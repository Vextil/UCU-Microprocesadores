#include <avr/io.h>

uint8_t digito = 0;

const uint8_t segment_table[10] = {
	0b00000011, // 0
	0b10011111, // 1
	0b00100101, // 2
	0b00001101, // 3
	0b10011001, // 4
	0b01001001, // 5
	0b01000001, // 6
	0b00011111, // 7
	0b00000001, // 8
	0b00001001  // 9
};

void sacanum(uint8_t num, uint8_t digit);
void dato_serie(uint8_t value);

void sacanum(uint8_t valor, uint8_t digitoSalida) {
	uint8_t value = segment_table[valor];
	dato_serie(value);
	dato_serie(digitoSalida);
	PORTD |= (1 << 4); // pongo el bit 4 de PORTD a alto (prende PD4) con un OR bit a bit
	PORTD &= ~(1 << 4); // limpio el bit 4 de PORTD (apaga PD4) con un AND NOT bit a bit
}

void dato_serie(uint8_t val) {
	for (uint8_t i = 0; i < 8; i++) {  // para cada bit del valor
		PORTD &= ~(1 << 7);  // bajo SCLK (PORTD7) con un AND NOT bit a bit
		if (val & 0b00000001) {
			PORTB = 1;  // subo SD (PORTB0) si el bit es 1 con un OR bit a bit
		} else {
			PORTB = 0;  // bajo SD (PORTB0) si el bit es 0 con un AND NOT bit a bit
		}
		val >>= 1;  // desplazo el valor a la derecha para procesar el siguiente bit
		PORTD |= (1 << 7);  // subo SCLK (PORTD7) con un OR bit a bit
	}
}

uint16_t adc_leer() {
    ADMUX &= 0b11111000; // configuro el registro ADMUX para seleccionar el canal ADC
	uint8_t mascara_adsc = 1 << ADSC;
    ADCSRA |= mascara_adsc; // inicio la conversión ADC con el bit ADSC en el registro ADCSRA
    while (ADCSRA & mascara_adsc); // espero a que la conversión termine (el bit ADSC se limpia cuando termina)
    return ADC;
}

uint16_t adc_prom() {
	uint16_t max = 10;
	uint32_t sum = 0;
	for (uint8_t i = 0; i < max; i++) {
		sum += adc_leer();
	}
	return (uint16_t)(sum / max);
}

float adc_a_voltaje(uint16_t adc) {
	return (adc * 5.0) / 1024.0;
}

void actualizar_pantalla(float volt) {
	uint16_t volt_int = (uint16_t)(volt * 1000); // convierto a un integer (ej 3.45V a 3450)
	uint8_t digito3 = volt_int % 10; // agarro el digito menos significativo
	volt_int /= 10;
	uint8_t digito2 = volt_int % 10;
	volt_int /= 10;
	uint8_t digito1 = volt_int % 10;
	volt_int /= 10;
	uint8_t digito0 = volt_int % 10; // agarro el digito mas significativo
	
	switch (digito) {
		case 0:
		sacanum(digito0, 0b10000000);
		digito = 1;
		break;
		case 1:
		sacanum(digito1, 0b01000000);
		digito = 2;
		break;
		case 2:
		sacanum(digito2, 0b00100000);
		digito = 3;
		break;
		case 3:
		sacanum(digito3, 0b00010000);
		digito = 0;
		break;
	}
}

int main() {
	DDRB = 0b00111101;
	DDRD = 0b10010000;
	ADMUX = (1 << REFS0); // selecciono un capacitor como referencia
	ADCSRA |= (1 << ADEN); // habilito el ADC
	ADCSRA |= (0b111 << ADPS0); // configuro el scaler a 128
	while (1) {
		uint16_t adc_resultado = adc_prom();
		float volt = adc_a_voltaje(adc_resultado);
		actualizar_pantalla(volt);
	}
}
