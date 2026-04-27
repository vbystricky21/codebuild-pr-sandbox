package com.example;

public final class App {

    private App() {
    }



    public static String greet(String name) {
        if (name == null || name.isBlank()) {
            return "Hello, world!";
        }
        return "Hello, " + name.strip() + "!";


    public static void main(String[] args) {
        System.out.println(greet(args.length > 0 ? args[0] : null));
    }
}
