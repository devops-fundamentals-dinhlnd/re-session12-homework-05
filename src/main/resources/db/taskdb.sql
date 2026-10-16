-- Tạo database nếu chưa tồn tại
CREATE DATABASE IF NOT EXISTS taskdb;
USE taskdb;

-- Tạo bảng tasks
CREATE TABLE IF NOT EXISTS tasks (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT FALSE
);

-- Chèn dữ liệu mẫu
INSERT INTO tasks (title, description, completed) VALUES
('Học Spring Boot', 'Tìm hiểu cơ bản về Spring Boot và tạo project đầu tiên', false),
('Cài đặt Docker', 'Cài đặt Docker Desktop và chạy thử container nginx', true),
('Viết REST API', 'Hoàn thành API /api/tasks lấy dữ liệu mock', false);
