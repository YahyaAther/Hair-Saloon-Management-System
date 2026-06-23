<?php
// api/controllers/ClientController.php
require_once __DIR__ . '/Controller.php';
require_once __DIR__ . '/../models/Client.php';
require_once __DIR__ . '/../middlewares/AuthMiddleware.php';

class ClientController extends Controller {
    private $clientModel;

    public function __construct() {
        $this->clientModel = new Client();
    }

    public function getClients() {
        AuthMiddleware::handle(['admin', 'receptionist']);
        $clients = $this->clientModel->getAll();
        $this->json($clients);
    }

    public function addClient() {
        AuthMiddleware::handle(['admin', 'receptionist']);
        
        $body = $this->getBody();
        $name = $body['name'] ?? '';
        $email = $body['email'] ?? '';
        $phone = $body['phone'] ?? '';

        if (empty($name)) {
            $this->json(['error' => 'Client name is required'], 400);
        }

        try {
            $id = $this->clientModel->create($name, $email, $phone);
            $this->json([
                'success' => true,
                'message' => 'Client added successfully',
                'id' => $id
            ]);
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 400);
        }
    }
}
