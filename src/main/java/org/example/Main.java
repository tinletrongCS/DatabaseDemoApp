package org.example;

import org.example.database.DatabaseConnection;
import java.sql.Connection;

public class Main {
    public static void main(String[] args) {
        System.out.println("Start checking connection...");

        // Gọi hàm kết nối
        Connection conn = DatabaseConnection.getConnection();

        if (conn != null) {
            System.out.println("Success");
        } else {
            System.out.println("Failed");
        }
    }
}