<?php
// api/models/Service.php
require_once __DIR__ . '/Model.php';

class Service extends Model {
    public function getAll() {
        $stmt = $this->db->query("SELECT * FROM services ORDER BY category ASC, name ASC");
        return $stmt->fetchAll();
    }

    public function create($name, $description, $durationMins, $price, $category) {
        $stmt = $this->db->prepare("
            INSERT INTO services (name, description, duration_mins, price, category) 
            VALUES (:name, :description, :duration_mins, :price, :category)
        ");
        $stmt->execute([
            'name' => $name,
            'description' => $description,
            'duration_mins' => $durationMins,
            'price' => $price,
            'category' => $category
        ]);
        return $this->db->lastInsertId();
    }

    public function update($id, $name, $description, $durationMins, $price, $category) {
        $stmt = $this->db->prepare("
            UPDATE services 
            SET name = :name, description = :description, duration_mins = :duration_mins, price = :price, category = :category 
            WHERE id = :id
        ");
        return $stmt->execute([
            'name' => $name,
            'description' => $description,
            'duration_mins' => $durationMins,
            'price' => $price,
            'category' => $category,
            'id' => $id
        ]);
    }
}
