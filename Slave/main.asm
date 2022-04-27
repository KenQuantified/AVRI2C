.cseg
;define SRAM storage location for received data
.equ SPIRx = 0x6000	;Rx data storage location
.equ RxBytes = 0x23	;number of Rx Bytes
.def RxC = r19		;receiver counter register
.def RState = r21	;State register
.def RC = r16		;common register
.def RI = r17		;interrupt register

;setup interrupt vectors
.org 0x0000
rjmp init
.org NMI_vect
reti
.org BOD_VLM_vect
reti
.org RTC_CNT_vect
reti
.org RTC_PIT_vect
reti
.org CCL_CCL_vect
reti
.org PORTA_PORT_vect
rjmp enablespiread
.org TCA0_OVF_vect
reti
.org TCA0_HUNF_vect
reti
.org TCA0_LCMP0_vect
reti
.org TCA0_LCMP1_vect
reti
.org TCA0_LCMP2_vect
reti
.org TCB0_INT_vect
reti
.org TCB1_INT_vect
reti
.org TCD0_OVF_vect
reti
.org TCD0_TRIG_vect
reti
.org TWI0_TWIS_vect
reti
.org TWI0_TWIM_vect
reti
.org SPI0_INT_vect
rjmp spiinterrupt
.org USART0_RXC_vect
reti
.org USART0_DRE_vect
reti
.org USART0_TXC_vect
reti
.org PORTD_PORT_vect
reti
.org AC0_AC_vect
reti
.org ADC0_RESRDY_vect
reti
.org ADC0_WCMP_vect
reti
.org ZCD0_ZCD_vect
reti
.org PTC_PTC_vect
reti
.org AC1_AC_vect
reti
.org PORTC_PORT_vect
reti
.org TCB2_INT_vect
reti
.org USART1_RXC_vect
reti
.org USART1_DRE_vect
reti
.org USART1_TXC_vect
reti
.org PORTF_PORT_vect
reti
.org NVMCTRL_EE_vect
reti
.org SPI1_INT_vect
reti
.org USART2_RXC_vect
reti
.org USART2_DRE_vect
reti
.org USART2_TXC_vect
reti
.org AC2_AC_vect
reti

;initialize controller at start
init:
	;PA5 is an output
	ldi RC, 0b00100000 ;for the slave only miso is an output
	ldi XH, High(PORTA_DIRSET)
	ldi XL, Low(PORTA_DIRSET)
	st X, RC

	;configure SPI Slave
	;setup CTRLA
	ldi RC, 0b00000000 ;default values are fine for now, enable will happen at the end.
	ldi XH, High(SPI0_CTRLA)
	ldi XL, Low(SPI0_CTRLA)
	st X, RC
	;setup CTRLB
	ldi RC, 0b10000001 ;set bit for BUFEN, BUFWR otherwise defaults are fine.
	ldi XH, High(SPI0_CTRLB)
	ldi XL, Low(SPI0_CTRLB)
	st X, RC
	
	ldi RState, 0x00 ;state machine variable

	rjmp runloop

runloop:
	;state machine
	cpi RState, 0x00 ;state 0x00, enable spi and SS Interrupt
	breq enablespi
	;state 0x01 is a wait state for the SS
	;state 0x02 is read state
	rjmp runloop

enablespi:
	;enable spi
	ldi RC, 0b00000001 ;default values are fine for now, enable now.
	ldi XH, High(SPI0_CTRLA)
	ldi XL, Low(SPI0_CTRLA)
	st X, RC
	;setup the interrupts for SS only right now
	ldi RC, 0b00000011 ;set falling edge interrupt on PA7
	ldi XH, High(PORTA_PIN7CTRL)
	ldi XL, Low(PORTA_PIN7CTRL)
	st X, RC

	inc RState

	sei
	
	rjmp runloop
	
enablespiread:
	;setup the interrupts for read only
	ldi RC, 0b10000001
	ldi XH, High(SPI0_INTCTRL)
	ldi XL, Low(SPI0_INTCTRL)
	st X, RC
	;disable interrupts for SS
	ldi RC, 0b00000000 ;unset falling edge interrupt on PA7
	ldi XH, High(PORTA_PIN7CTRL)
	ldi XL, Low(PORTA_PIN7CTRL)
	st X, RC
	ldi RC, 0b10000000 ;clear interrupt flag
	ldi XH, High(PORTA_INTFLAGS)
	ldi XL, Low(PORTA_INTFLAGS)
	st X, RC

	ldi RxC, 0x00

	inc RState
	
	reti

spiinterrupt:
	ldi YH, High(SPI0_DATA)
	ldi YL, Low(SPI0_DATA)
	ld RI, Y
	ldi YH, High(SPIRx)
	ldi YL, Low(SPIRx)
	add YL, RxC
	st Y, RI

	inc RxC
	cpi RxC, RxBytes
	breq advancestate

	reti

advancestate:
	cli
	inc RState
	ldi RxC, 0x00

	reti