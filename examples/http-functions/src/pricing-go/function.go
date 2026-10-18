// Package pricing returns a price quote for a product ID.
package pricing

import (
	"encoding/json"
	"net/http"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
)

func init() {
	functions.HTTP("Quote", quote)
}

func quote(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"product": r.URL.Query().Get("id"), "price": 9.99})
}
