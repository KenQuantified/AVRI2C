.eseg
.org 0x0000
.db "Master Data Send and now more bytes"

.cseg
;define SRAM storage location for received data
.equ SPITx = 0x1400	;Tx data location
.equ TxBytes = 0x25	;number of Tx Bytes 0x23+0x02
.def TxC = r18		;transmit counter register
.def SC = r19		;sleep counter
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
reti
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
	;configure PORT A
	ldi RC, 0b00001111 ;disable ports PA0-3
	ldi XH, High(PORTA_PINCTRLUPD)
	ldi XL, Low(PORTA_PINCTRLUPD)
	st X, RC
	;PA5 is an output
	ldi RC, 0b11010000 ;for the slave only miso is an output
	ldi XH, High(PORTA_DIRSET)
	ldi XL, Low(PORTA_DIRSET)
	st X, RC

	;configure PORT C
	;nothing on PORT C
	ldi RC, 0b11111111
	ldi XH, High(PORTC_PINCTRLUPD)
	ldi XL, Low(PORTC_PINCTRLUPD)
	st X, RC

	;configure PORT D
	;nothing on PORT D
	ldi RC, 0b11111111
	ldi XH, High(PORTD_PINCTRLUPD)
	ldi XL, Low(PORTD_PINCTRLUPD)
	st X, RC

	;configure PORT F
	;nothing on PORT F
	ldi RC, 0b11111111 ;disable all
	ldi XH, High(PORTF_PINCTRLUPD)
	ldi XL, Low(PORTF_PINCTRLUPD)
	st X, RC

	;start with slaves deselected
	ldi RC, 0b10000000 ;pull SS high so the slave is disabled initially
	ldi XH, High(PORTA_OUTSET)
	ldi XL, Low(PORTA_OUTSET)
	st X, RC

	;configure SPI Master
	;setup CTRLA
	ldi RC, 0b00100010 ;default values are fine for now other than setting the master enable will happen at the end.
	ldi XH, High(SPI0_CTRLA)
	ldi XL, Low(SPI0_CTRLA)
	st X, RC
	;setup CTRLB
	ldi RC, 0b10000101 ;set bit for BUFEN, BUFWR otherwise defaults are fine.
	ldi XH, High(SPI0_CTRLB)
	ldi XL, Low(SPI0_CTRLB)
	st X, RC
		
	ldi RState, 0x00 ;state machine variable

	rjmp runloop

runloop:
	;state machine
	cpi RState, 0x00 ;state 0x00, enable spi and SS Interrupt
	breq enablespi
	;state 0x01 is a wait state for tx
	cpi RState, 0x02 ;Tx is done, go to sleep
	breq disableslave
	cpi RState, 0x03 ;'sleep state'
	breq incrementcounter
	rjmp runloop

incrementcounter:
	inc SC
	brvs resetstate

	rjmp runloop

resetstate:
	ldi RState, 0x00

	rjmp runloop

enablespi:
	;enable spi
	ldi RC, 0b00100011 ;default values are fine for now, enable now.
	ldi XH, High(SPI0_CTRLA)
	ldi XL, Low(SPI0_CTRLA)
	st X, RC
	;setup the interrupts for write
	ldi RC, 0b01100001
	ldi XH, High(SPI0_INTCTRL)
	ldi XL, Low(SPI0_INTCTRL)
	st X, RC

	;select slave
	ldi RC, 0b10000000 ;pull SS low to enable the receiver
	ldi XH, High(PORTA_OUTCLR)
	ldi XL, Low(PORTA_OUTCLR)
	st X, RC

	ldi TxC, 0x00

	inc RState

	sei
	
	rjmp runloop

disableslave:
	;disable slave
	ldi RC, 0b10000000 ;pull SS high so the slave is disabled
	ldi XH, High(PORTA_OUTSET)
	ldi XL, Low(PORTA_OUTSET)
	st X, RC
	;disable interrupts
	ldi RC, 0b00000000
	ldi XH, High(SPI0_INTCTRL)
	ldi XL, Low(SPI0_INTCTRL)
	st X, RC

	inc RState
	ldi SC, 0x00

	rjmp runloop

spiinterrupt:
	ldi YH, High(SPITx)
	ldi YL, Low(SPITx)
	add YL, TxC
	ld RI, Y
	ldi YH, High(SPI0_DATA)
	ldi YL, Low(SPI0_DATA)
	st Y, RI

	inc TxC

	cpi TxC, TxBytes
	breq advancestate

	reti

advancestate:
	inc RState
	ldi TxC, 0x00

	reti