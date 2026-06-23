<?php
// api/models/Model.php
require_once __DIR__ . '/../core/Database.php';

class Model {
    protected $db;

    public function __construct() {
        $this->db = Database::getConnection();
    }
}
