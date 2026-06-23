<?php
// api/db.php - Compatibility bridge to new OOP Database connection
require_once __DIR__ . '/core/Database.php';
$pdo = Database::getConnection();
