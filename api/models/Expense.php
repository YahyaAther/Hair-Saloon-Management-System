<?php
// api/models/Expense.php
require_once __DIR__ . '/Model.php';

class Expense extends Model {
    public function getAll() {
        $stmt = $this->db->query("
            SELECT e.*, u.name as logged_by_name
            FROM expenses e
            JOIN users u ON e.logged_by = u.id
            ORDER BY e.expense_date DESC, e.created_at DESC
        ");
        return $stmt->fetchAll();
    }

    public function create($category, $amount, $description, $expenseDate, $loggedBy) {
        $this->db->beginTransaction();
        try {
            $stmt = $this->db->prepare("
                INSERT INTO expenses (category, amount, description, expense_date, logged_by)
                VALUES (:category, :amount, :description, :expense_date, :logged_by)
            ");
            $stmt->execute([
                'category' => $category,
                'amount' => $amount,
                'description' => $description,
                'expense_date' => $expenseDate,
                'logged_by' => $loggedBy
            ]);
            $expenseId = $this->db->lastInsertId();

            // Update Cash Reconciliation
            $stmt = $this->db->prepare("
                SELECT id FROM cash_reconciliation 
                WHERE reconciliation_date = :date AND status = 'open'
            ");
            $stmt->execute(['date' => $expenseDate]);
            $recon = $stmt->fetch();

            if ($recon) {
                $stmt = $this->db->prepare("
                    UPDATE cash_reconciliation 
                    SET logged_expenses = logged_expenses + :amount,
                        closing_balance = closing_balance - :amount
                    WHERE id = :id
                  ");
                $stmt->execute(['amount' => $amount, 'id' => $recon['id']]);
            } else {
                $openingCash = 200.0;
                $closingBalance = $openingCash - $amount;
                $stmt = $this->db->prepare("
                    INSERT INTO cash_reconciliation (reconciliation_date, opening_cash, total_cash_sales, digital_payments, logged_expenses, closing_balance, status)
                    VALUES (:date, :opening_cash, 0.0, 0.0, :logged_expenses, :closing_balance, 'open')
                ");
                $stmt->execute([
                    'date' => $expenseDate,
                    'opening_cash' => $openingCash,
                    'logged_expenses' => $amount,
                    'closing_balance' => $closingBalance
                ]);
            }

            $this->db->commit();
            return $expenseId;
        } catch (Exception $e) {
            $this->db->rollBack();
            throw $e;
        }
    }
}
