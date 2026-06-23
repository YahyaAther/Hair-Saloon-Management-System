<?php
// api/models/Client.php
require_once __DIR__ . '/Model.php';

class Client extends Model {
    public function getAll() {
        $stmt = $this->db->query("SELECT * FROM clients ORDER BY name ASC");
        return $stmt->fetchAll();
    }

    public function create($name, $email, $phone) {
        $stmt = $this->db->prepare("INSERT INTO clients (name, email, phone) VALUES (:name, :email, :phone)");
        $stmt->execute([
            'name' => $name,
            'email' => $email,
            'phone' => $phone
        ]);
        return $this->db->lastInsertId();
    }

    public function findOrCreate($name, $email, $phone) {
        $stmt = $this->db->prepare("SELECT id FROM clients WHERE (email = :email AND :email != '') OR (phone = :phone AND :phone != '') LIMIT 1");
        $stmt->execute(['email' => $email, 'phone' => $phone]);
        $id = $stmt->fetchColumn();
        
        if ($id) {
            return $id;
        }
        return $this->create($name, $email, $phone);
    }
}
