package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/", helloWorld)
	http.HandleFunc("/health", healthCheck)

	port := getEnv("PORT", "8080")
	log.Printf("Server starting on port %s\n", port)
	if err := http.ListenAndServe(fmt.Sprintf(":%s", port), nil); err != nil {
		log.Fatal(err)
	}
}

func helloWorld(w http.ResponseWriter, r *http.Request) {
	log.Printf("Received request for %s from %s", r.URL.Path, r.RemoteAddr)
	hostname, _ := os.Hostname()
	fmt.Fprintf(w, "Hello, World from %s! Welcome to Cloud Native Infrastructure.\n", hostname)
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "OK")
}

func getEnv(key, fallback string) string {
	value, exists := os.LookupEnv(key)
	if !exists {
		value = fallback
	}
	return value
}
