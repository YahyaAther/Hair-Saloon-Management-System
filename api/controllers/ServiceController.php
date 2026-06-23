<?php
// api/controllers/ServiceController.php
require_once __DIR__ . '/Controller.php';
require_once __DIR__ . '/../models/Service.php';
require_once __DIR__ . '/../middlewares/AuthMiddleware.php';

class ServiceController extends Controller {
    private $serviceModel;

    public function __construct() {
        $this->serviceModel = new Service();
    }

    public function getServices() {
        $services = $this->serviceModel->getAll();
        $this->json($services);
    }

    public function addService() {
        AuthMiddleware::handle(['admin', 'receptionist']);
        
        $body = $this->getBody();
        $name = $body['name'] ?? '';
        $description = $body['description'] ?? '';
        $durationMins = intval($body['duration_mins'] ?? 0);
        $price = floatval($body['price'] ?? 0.0);
        $category = $body['category'] ?? '';

        if (empty($name) || $durationMins <= 0 || $price < 0.0 || empty($category)) {
            $this->json(['error' => 'Missing or invalid service details'], 400);
        }

        try {
            $id = $this->serviceModel->create($name, $description, $durationMins, $price, $category);
            $this->json([
                'success' => true,
                'message' => 'Service added successfully',
                'id' => $id
            ]);
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 400);
        }
    }

    public function updateService() {
        AuthMiddleware::handle(['admin', 'receptionist']);
        
        $body = $this->getBody();
        $id = intval($body['id'] ?? 0);
        $name = $body['name'] ?? '';
        $description = $body['description'] ?? '';
        $durationMins = intval($body['duration_mins'] ?? 0);
        $price = floatval($body['price'] ?? 0.0);
        $category = $body['category'] ?? '';

        if (empty($id) || empty($name) || $durationMins <= 0 || $price < 0.0 || empty($category)) {
            $this->json(['error' => 'Missing or invalid service details'], 400);
        }

        try {
            $this->serviceModel->update($id, $name, $description, $durationMins, $price, $category);
            $this->json([
                'success' => true,
                'message' => 'Service updated successfully'
            ]);
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 400);
        }
    }
}
