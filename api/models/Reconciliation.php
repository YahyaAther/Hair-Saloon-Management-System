<?php
// api/models/Reconciliation.php
require_once __DIR__ . '/Model.php';

class Reconciliation extends Model {
    public function getAll() {
        $stmt = $this->db->query("
            SELECT r.*, u.name as closed_by_name
            FROM cash_reconciliation r
            LEFT JOIN users u ON r.closed_by = u.id
            ORDER BY r.reconciliation_date DESC
        ");
        return $stmt->fetchAll();
    }

    public function getTodayStatus() {
        $date = date('Y-m-d');
        $stmt = $this->db->prepare("SELECT * FROM cash_reconciliation WHERE reconciliation_date = :date");
        $stmt->execute(['date' => $date]);
        $recon = $stmt->fetch();
        
        if (!$recon) {
            // Auto-initialize opening cash at $200.00
            $stmt = $this->db->prepare("
                INSERT INTO cash_reconciliation (reconciliation_date, opening_cash, total_cash_sales, digital_payments, logged_expenses, closing_balance, status)
                VALUES (:date, 200.00, 0.0, 0.0, 0.0, 200.00, 'open')
            ");
            $stmt->execute(['date' => $date]);
            
            $stmt2 = $this->db->prepare("SELECT * FROM cash_reconciliation WHERE reconciliation_date = :date");
            $stmt2->execute(['date' => $date]);
            $recon = $stmt2->fetch();
        }
        return $recon;
    }

    public function closeDrawer($date, $closingBalance, $closedById) {
        $stmt = $this->db->prepare("
            UPDATE cash_reconciliation 
            SET closing_balance = :closing_balance,
                status = 'closed',
                closed_by = :closed_by,
                closed_at = CURRENT_TIMESTAMP
            WHERE reconciliation_date = :date AND status = 'open'
        ");
        return $stmt->execute([
            'closing_balance' => $closingBalance,
            'closed_by' => $closedById,
            'date' => $date
        ]);
    }
}
