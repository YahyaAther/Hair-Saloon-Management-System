<?php
// api/models/Product.php
require_once __DIR__ . '/Model.php';

class Product extends Model {
    public function getAll() {
        $stmt = $this->db->query("SELECT * FROM products ORDER BY category ASC, name ASC");
        return $stmt->fetchAll();
    }

    public function getLowStockAlerts() {
        $stmt = $this->db->query("
            SELECT * FROM products 
            WHERE stock_quantity <= min_stock_alert
            ORDER BY stock_quantity ASC
        ");
        return $stmt->fetchAll();
    }
}
