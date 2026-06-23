<?php
// api/controllers/ExpenseController.php
require_once __DIR__ . '/Controller.php';
require_once __DIR__ . '/../models/Expense.php';
require_once __DIR__ . '/../middlewares/AuthMiddleware.php';

class ExpenseController extends Controller {
    private $expenseModel;

    public function __construct() {
        $this->expenseModel = new Expense();
    }

    public function getExpenses() {
        AuthMiddleware::handle(['admin', 'receptionist', 'stylist']);
        $expenses = $this->expenseModel->getAll();
        $this->json($expenses);
    }

    public function logExpense() {
        $user = AuthMiddleware::handle(['admin', 'receptionist', 'stylist']);
        
        $body = $this->getBody();
        $category = $body['category'] ?? '';
        $amount = floatval($body['amount'] ?? 0.0);
        $description = $body['description'] ?? '';
        $expenseDate = $body['expense_date'] ?? date('Y-m-d');

        if (empty($category) || $amount <= 0.0) {
            $this->json(['error' => 'Expense category and positive amount are required'], 400);
        }

        try {
            $expenseId = $this->expenseModel->create($category, $amount, $description, $expenseDate, $user['id']);
            $this->json([
                'success' => true,
                'message' => 'Expense logged successfully',
                'expense_id' => $expenseId
            ]);
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 400);
        }
    }
}
