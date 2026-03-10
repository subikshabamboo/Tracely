package testdata

import (
	"github.com/brianvoe/gofakeit/v6"
)

type Generator struct{}

func (g *Generator) GenerateUser() map[string]interface{} {
	gofakeit.Seed(0)
	return map[string]interface{}{
		"name":    gofakeit.Name(),
		"email":   gofakeit.Email(),
		"address": gofakeit.Address().Address,
		"phone":   gofakeit.Phone(),
	}
}

func (g *Generator) GenerateCard() map[string]interface{} {
	return map[string]interface{}{
		"number": gofakeit.CreditCardNumber(nil),
		"expiry": gofakeit.CreditCardExp(),
		"type":   gofakeit.CreditCardType(),
	}
}


