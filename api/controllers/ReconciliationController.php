<?php
// api/controllers/ReconciliationController.php
require_once __DIR__ . '/Controller.php';
require_once __DIR__ . '/../models/Reconciliation.php';
require_once __DIR__ . '/../middlewares/AuthMiddleware.php';

class ReconciliationController extends Controller {
    private $reconModel;

    public function __construct() {
        $this->reconModel = new Reconciliation();
    }

    public function getReconciliations() {
        AuthMiddleware::handle(['admin', 'receptionist']);
        $recons = $this->reconModel->getAll();
        $this->json($recons);
    }

    public function getTodayStatus() {
        AuthMiddleware::handle(['admin', 'receptionist']);
        $today = $this->reconModel->getTodayStatus();
        $this->json($today);
    }

    public function closeDrawer() {
        $user = AuthMiddleware::handle(['admin', 'receptionist']);
        
        $body = $this->getBody();
        $date = $body['date'] ?? date('Y-m-d');
        $closingBalance = floatval($body['closing_balance'] ?? 0.0);

        try {
            $success = $this->reconModel->closeDrawer($date, $closingBalance, $user['id']);
            if ($success) {
                $this->json(['success' => true, 'message' => 'Cash drawer reconciled and closed successfully']);
            } else {
                $this->json(['error' => 'Failed to close cash drawer. Make sure it is not already closed.'], 400);
            }
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 400);
        }
    }
}
