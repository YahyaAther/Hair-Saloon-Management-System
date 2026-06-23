<?php
// api/controllers/InventoryController.php
require_once __DIR__ . '/Controller.php';
require_once __DIR__ . '/../models/Product.php';
require_once __DIR__ . '/../middlewares/AuthMiddleware.php';
require_once __DIR__ . '/../core/Database.php';

class InventoryController extends Controller {
    private $productModel;

    public function __construct() {
        $this->productModel = new Product();
    }

    public function getInventory() {
        AuthMiddleware::handle(['admin', 'receptionist', 'stylist']);
        $products = $this->productModel->getAll();
        $this->json($products);
    }

    public function getLowStockAlerts() {
        AuthMiddleware::handle(['admin', 'receptionist']);
        $alerts = $this->productModel->getLowStockAlerts();
        $this->json($alerts);
    }

    public function addProduct() {
        AuthMiddleware::handle(['admin', 'receptionist']);
        
        $body = $this->getBody();
        $name = $body['name'] ?? '';
        $description = $body['description'] ?? '';
        $price = floatval($body['price'] ?? 0.0);
        $stockQuantity = floatval($body['stock_quantity'] ?? 0.0);
        $category = $body['category'] ?? ''; // salon_consumption, retail_sale
        $minStockAlert = floatval($body['min_stock_alert'] ?? 0.0);

        if (empty($name) || empty($category)) {
            $this->json(['error' => 'Product name and category are required'], 400);
        }

        if (!in_array($category, ['salon_consumption', 'retail_sale'])) {
            $this->json(['error' => 'Invalid category specified'], 400);
        }

        try {
            $db = Database::getConnection();
            $stmt = $db->prepare("
                INSERT INTO products (name, description, price, stock_quantity, category, min_stock_alert)
                VALUES (:name, :description, :price, :stock_quantity, :category, :min_stock_alert)
            ");
            $stmt->execute([
                'name' => $name,
                'description' => $description,
                'price' => $price,
                'stock_quantity' => $stockQuantity,
                'category' => $category,
                'min_stock_alert' => $minStockAlert
            ]);
            $this->json([
                'success' => true,
                'message' => 'Product added successfully',
                'id' => $db->lastInsertId()
            ]);
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 400);
        }
    }

    public function updateStock() {
        AuthMiddleware::handle(['admin', 'receptionist']);
        
        $body = $this->getBody();
        $id = $body['id'] ?? null;
        $quantity = floatval($body['quantity'] ?? 0.0);

        if (!$id) {
            $this->json(['error' => 'Product ID is required'], 400);
        }

        try {
            $db = Database::getConnection();
            $stmt = $db->prepare("UPDATE products SET stock_quantity = stock_quantity + :qty WHERE id = :id");
            $stmt->execute(['qty' => $quantity, 'id' => $id]);
            $this->json(['success' => true, 'message' => 'Stock updated successfully']);
        } catch (Exception $e) {
            $this->json(['error' => $e->getMessage()], 400);
        }
    }
}
