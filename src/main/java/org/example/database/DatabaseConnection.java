package org.example.database;

import java.sql.Connection;
import java.sql.DriverManager;

public class DatabaseConnection {
    public static Connection getConnection() {
        String dbURL = "";
        String dbUser = "";
        String dbPassword = "";

        try {
            Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
            Connection conn = DriverManager.getConnection(dbURL, dbUser, dbPassword);
            System.out.println("Ket noi database thanh cong"); // In ra để biết là OK
            return conn;
        } catch (Exception ex) {
            System.out.println("Ket noi that bai: " + ex.getMessage());
            ex.printStackTrace();
        }
        return null;
    }
}