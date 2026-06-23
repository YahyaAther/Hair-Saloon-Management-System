<?php
// api/controllers/Controller.php

class Controller {
    protected function json($data, $status = 200) {
        http_response_code($status);
        echo json_encode($data);
        exit();
    }

    protected function getBody() {
        return json_decode(file_get_contents('php://input'), true) ?? [];
    }
}
