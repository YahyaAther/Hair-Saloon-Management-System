<?php
// api/models/Invoice.php
require_once __DIR__ . '/Model.php';

class Invoice extends Model {
    public function createCheckout($clientId, $loggedById, $paymentMethod, $items, $appointmentId = null) {
        $this->db->beginTransaction();
        try {
            $totalAmount = 0.0;
            
            // Calculate total amount first to save invoice
            foreach ($items as $item) {
                $totalAmount += floatval($item['price']) * intval($item['quantity']);
            }

            // 1. Create Invoice
            $stmt = $this->db->prepare("
                INSERT INTO invoices (client_id, logged_by, payment_method, payment_status, total_amount, appointment_id, created_at)
                VALUES (:client_id, :logged_by, :payment_method, 'paid', :total_amount, :appointment_id, :created_at)
            ");
            $stmt->execute([
                'client_id' => $clientId,
                'logged_by' => $loggedById,
                'payment_method' => $paymentMethod,
                'total_amount' => $totalAmount,
                'appointment_id' => $appointmentId,
                'created_at' => date('Y-m-d H:i:s')
            ]);
            $invoiceId = $this->db->lastInsertId();

            // 2. Add Invoice Items, compute commissions and update inventory
            foreach ($items as $item) {
                $itemType = $item['item_type']; // service or product
                $itemId = $item['item_id'];
                $stylistId = $item['stylist_id'] ?? null;
                $quantity = intval($item['quantity']);
                $price = floatval($item['price']);
                
                $commissionPaid = 0.0;
                
                if ($stylistId) {
                    // Fetch stylist's commission profile
                    $stmt = $this->db->prepare("
                        SELECT u.commission_rate, u.commission_type 
                        FROM users u 
                        JOIN staff s ON u.id = s.user_id 
                        WHERE s.id = :staff_id
                    ");
                    $stmt->execute(['staff_id' => $stylistId]);
                    $stylist = $stmt->fetch();
                    
                    if ($stylist) {
                        $rate = floatval($stylist['commission_rate']);
                        $type = $stylist['commission_type'];
                        
                        if ($type === 'percentage') {
                            $commissionPaid = ($price * $quantity) * ($rate / 100.0);
                        } else {
                            $commissionPaid = $rate * $quantity;
                        }
                    }
                }

                // Insert Invoice Item
                $stmt = $this->db->prepare("
                    INSERT INTO invoice_items (invoice_id, item_type, item_id, stylist_id, quantity, price, commission_paid)
                    VALUES (:invoice_id, :item_type, :item_id, :stylist_id, :quantity, :price, :commission_paid)
                ");
                $stmt->execute([
                    'invoice_id' => $invoiceId,
                    'item_type' => $itemType,
                    'item_id' => $itemId,
                    'stylist_id' => $stylistId,
                    'quantity' => $quantity,
                    'price' => $price,
                    'commission_paid' => $commissionPaid
                ]);

                // Update product stock if it's a product
                if ($itemType === 'product') {
                    $stmt = $this->db->prepare("
                        UPDATE products 
                        SET stock_quantity = stock_quantity - :qty 
                        WHERE id = :id
                    ");
                    $stmt->execute(['qty' => $quantity, 'id' => $itemId]);
                }
            }

            // 3. Update Client Stats if client_id is set
            if ($clientId) {
                $date = date('Y-m-d');
                $stmt = $this->db->prepare("
                    UPDATE clients 
                    SET total_spent = total_spent + :amount, last_visit = :date 
                    WHERE id = :client_id
                ");
                $stmt->execute([
                    'amount' => $totalAmount,
                    'date' => $date,
                    'client_id' => $clientId
                ]);
            }

            // 4. Update Cash Reconciliation for Today
            $date = date('Y-m-d');
            $stmt = $this->db->prepare("
                SELECT id, opening_cash, total_cash_sales, digital_payments, logged_expenses, closing_balance 
                FROM cash_reconciliation 
                WHERE reconciliation_date = :date AND status = 'open'
            ");
            $stmt->execute(['date' => $date]);
            $recon = $stmt->fetch();

            if ($recon) {
                if ($paymentMethod === 'cash') {
                    $stmt = $this->db->prepare("
                        UPDATE cash_reconciliation 
                        SET total_cash_sales = total_cash_sales + :amount,
                            closing_balance = closing_balance + :amount
                        WHERE id = :id
                    ");
                    $stmt->execute(['amount' => $totalAmount, 'id' => $recon['id']]);
                } else {
                    $stmt = $this->db->prepare("
                        UPDATE cash_reconciliation 
                        SET digital_payments = digital_payments + :amount
                        WHERE id = :id
                    ");
                    $stmt->execute(['amount' => $totalAmount, 'id' => $recon['id']]);
                }
            } else {
                $openingCash = 200.0; // default standard opening cash
                $cashSales = ($paymentMethod === 'cash') ? $totalAmount : 0.0;
                $digitalSales = ($paymentMethod === 'digital') ? $totalAmount : 0.0;
                $closingBalance = $openingCash + $cashSales;
                
                $stmt = $this->db->prepare("
                    INSERT INTO cash_reconciliation (reconciliation_date, opening_cash, total_cash_sales, digital_payments, logged_expenses, closing_balance, status)
                    VALUES (:date, :opening_cash, :total_cash_sales, :digital_payments, 0.0, :closing_balance, 'open')
                ");
                $stmt->execute([
                    'date' => $date,
                    'opening_cash' => $openingCash,
                    'total_cash_sales' => $cashSales,
                    'digital_payments' => $digitalSales,
                    'closing_balance' => $closingBalance
                ]);
            }

            $this->db->commit();
            return $invoiceId;
        } catch (Exception $e) {
            $this->db->rollBack();
            throw $e;
        }
    }

    public function createFromCompletedAppointment($appointmentId, $loggedById) {
        $stmt = $this->db->prepare("SELECT id FROM invoices WHERE appointment_id = :appointment_id");
        $stmt->execute(['appointment_id' => $appointmentId]);
        if ($stmt->fetch()) {
            return; // Already invoiced
        }

        $stmt = $this->db->prepare("
            SELECT a.client_id, a.staff_id, a.service_id, s.price 
            FROM appointments a 
            JOIN services s ON a.service_id = s.id 
            WHERE a.id = :id
        ");
        $stmt->execute(['id' => $appointmentId]);
        $apt = $stmt->fetch();
        if (!$apt) return;

        $clientId = $apt['client_id'];
        $staffId = $apt['staff_id'];
        $serviceId = $apt['service_id'];
        $price = floatval($apt['price']);

        $items = [
            [
                'item_type' => 'service',
                'item_id' => $serviceId,
                'stylist_id' => $staffId,
                'quantity' => 1,
                'price' => $price
            ]
        ];

        // Default auto-checkout payment method to cash
        $this->createCheckout($clientId, $loggedById, 'cash', $items, $appointmentId);
    }

    public function getAll() {
        $stmt = $this->db->query("
            SELECT i.*, c.name as client_name, u.name as cashier_name
            FROM invoices i
            LEFT JOIN clients c ON i.client_id = c.id
            JOIN users u ON i.logged_by = u.id
            ORDER BY i.created_at DESC
        ");
        return $stmt->fetchAll();
    }

    public function getCommissionReport() {
        $stmt = $this->db->query("
            SELECT s.id as staff_id, s.name as stylist_name, s.role, 
                   COALESCE(SUM(ii.commission_paid), 0.0) as total_commission_earned
            FROM staff s
            LEFT JOIN invoice_items ii ON s.id = ii.stylist_id
            GROUP BY s.id
            ORDER BY total_commission_earned DESC
        ");
        return $stmt->fetchAll();
    }

    public function getStylistPayouts($userId) {
        // Fetch stylus commission details filtered by user id
        $stmt = $this->db->prepare("
            SELECT ii.*, inv.created_at, s.name as service_name, p.name as product_name
            FROM invoice_items ii
            JOIN invoices inv ON ii.invoice_id = inv.id
            JOIN staff st ON ii.stylist_id = st.id
            LEFT JOIN services s ON ii.item_type = 'service' AND ii.item_id = s.id
            LEFT JOIN products p ON ii.item_type = 'product' AND ii.item_id = p.id
            WHERE st.user_id = :user_id
            ORDER BY inv.created_at DESC
        ");
        $stmt->execute(['user_id' => $userId]);
        return $stmt->fetchAll();
    }
}
