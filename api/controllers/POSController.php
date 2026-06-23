<?php
// api/controllers/POSController.php
require_once __DIR__ . '/Controller.php';
require_once __DIR__ . '/../models/Invoice.php';
require_once __DIR__ . '/../middlewares/AuthMiddleware.php';

class POSController extends Controller {
    private $invoiceModel;

    public function __construct() {
        $this->invoiceModel = new Invoice();
    }

    public function checkout() {
        $user = AuthMiddleware::handle(['admin', 'receptionist']);
        
        $body = $this->getBody();
        $clientId = $body['client_id'] ?? null;
        $paymentMethod = $body['payment_method'] ?? ''; // cash, digital
        $items = $body['items'] ?? [];

        if (empty($paymentMethod) || empty($items)) {
            $this->json(['error' => 'Payment method and checkout items are required'], 400);
        }

        try {
            $invoiceId = $this->invoiceModel->createCheckout($clientId, $user['id'], $paymentMethod, $items);
            $this->json([
                'success' => true,
                'message' => 'Checkout completed successfully',
                'invoice_id' => $invoiceId
            ]);
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 400);
        }
    }

    public function getCommissionReport() {
        AuthMiddleware::handle(['admin', 'receptionist']);
        $report = $this->invoiceModel->getCommissionReport();
        $this->json($report);
    }

    public function getStylistPayouts() {
        $user = AuthMiddleware::handle(['stylist']);
        $payouts = $this->invoiceModel->getStylistPayouts($user['id']);
        
        $totalEarned = 0.0;
        foreach ($payouts as $p) {
            $totalEarned += floatval($p['commission_paid']);
        }

        $this->json([
            'total_earned' => $totalEarned,
            'payouts' => $payouts
        ]);
    }
}
