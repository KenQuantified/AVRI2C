;
; I2C.asm
;
; Created: 2022-04-08 8:53:47 PM
; Author : kenqu
;

;define SRAM storage locations for sensor data
.equ TEMP = 0x6000 ;three bytes HT
.equ HUMIDITY = 0x6003 ;three bytes
.equ HT_Bytes = 0x06
.equ HT_Address = 0x44

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
rjmp twiinterrupt
.org SPI0_INT_vect
reti
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
	ldi r16, 0b11110011 ;disable ports PA0,1 and 4-7
	ldi XH, High(PORTA_PINCTRLUPD)
	ldi XL, Low(PORTA_PINCTRLUPD)
	st X, r16
	;PA3 and PA2 are outputs
	ldi r16, 0b00001100
	ldi XH, High(PORTA_DIRSET)
	ldi XL, Low(PORTA_DIRSET)
	st X, r16

	;configure PORT C
	;nothing on PORT C
	ldi r16, 0b11111111
	ldi XH, High(PORTC_PINCTRLUPD)
	ldi XL, Low(PORTC_PINCTRLUPD)
	st X, r16

	;configure PORT D
	;nothing on PORT D
	ldi r16, 0b11111111
	ldi XH, High(PORTD_PINCTRLUPD)
	ldi XL, Low(PORTD_PINCTRLUPD)
	st X, r16

	;configure PORT F
	;nothing on PORT F
	ldi r16, 0b11111111 ;disable all
	ldi XH, High(PORTF_PINCTRLUPD)
	ldi XL, Low(PORTF_PINCTRLUPD)
	st X, r16

	;configure TWI(I2C)
	;setup SDASETUP and SDAHOLD in CTRLA
	ldi r16, 0b00000000 ;i2c mode, 4cycle SDA Setup, no SDA Hold, FM+ Disabled
	ldi XH, High(TWI0_CTRLA)
	ldi XL, Low(TWI0_CTRLA)
	st X, r16
	;enable debug mode
	ldi r16, 0x01
	ldi XH, High(TWI0_DBGCTRL)
	ldi XL, Low(TWI0_DBGCTRL)
	st X, r16
	;set MBAUD ;400 kHz, SM/FM/FM+, BAUD of 2 should be okay?
	ldi r16, 0x02
	ldi XH, High(TWI0_MBAUD)
	ldi XL, Low(TWI0_MBAUD)
	st X, r16
	
	ldi r21, 0x00 ;state machine variable

	
	rjmp runloop

runloop:
	cpi r21, 0x00 ;state 0, enable twi and command measurement
	breq enabletwi
	cpi r21, 0x01 ;state 1, command rx
	breq commandrx
	;state 0x02 is just a wait state until all rx data is received
	cpi r21, 0x03 ;state 3 is disable twi
	breq disabletwi
	rjmp runloop

enabletwi:
	;enable r/w interrupts and master
	cli
	ldi r16, 0b11000001 ;interrupts on, QC off, timeout off, SM disabled, Enable master
	ldi XH, High(TWI0_MCTRLA)
	ldi XL, Low(TWI0_MCTRLA)
	st X, r16
	;Idle the bus (set MSTATUS BUSSTATE to 0x01)
	ldi r16, 0b00000001
	ldi XH, High(TWI0_MSTATUS)
	ldi XL, Low(TWI0_MSTATUS)
	st X, r16
	;send the address and write bit
	ldi r16, 0x88 ;address 0x44 + write bit 0
	ldi XH, High(TWI0_MADDR)
	ldi XL, Low(TWI0_MADDR)
	st X, r16
	sei
	
	rjmp runloop

commandrx:
	cli
	;send the address and read bit
	ldi r16, 0x89 ;address 0x44 + read bit 1
	ldi XH, High(TWI0_MADDR)
	ldi XL, Low(TWI0_MADDR)
	st X, r16
	ldi YH, High(TEMP)
	ldi YL, Low(TEMP)
	ldi r20, 0b00000000 ;r20 will be our rx byte counter
	inc r21
	sei
	
	rjmp runloop
    
disabletwi:
	cli
	ldi r16, 0b00000000 ;interrupts off, QC off, timeout off, SM disabled, disable master
	ldi XH, High(TWI0_MCTRLA)
	ldi XL, Low(TWI0_MCTRLA)
	st X, r16
	ldi r21, 0x00
	sei

	rjmp runloop

twiinterrupt:
	cli
	push r17
	push XH
	push XL
	push r16

	ldi XH, High(TWI0_MSTATUS)
	ldi XL, Low(TWI0_MSTATUS)
	ld r17, X
	sbrc r17, 7
	call readtwi
	sbrc r17, 6
	call writetwi

	pop r16
	pop XL
	pop XH
	pop r17
	sei

	reti

readtwi:
	ldi XH, High(TWI0_MDATA)
	ldi XL, Low(TWI0_MDATA)
	ld r16, X
	st Y+, r16

	ldi r16, 0x02
	ldi XH, High(TWI0_MCTRLB)
	ldi XL, Low(TWI0_MCTRLB)
	st X, r16

	inc r20

	cpi r20, 0x06
	breq movestate

	ret

movestate:
	inc r21
	ldi r16, 0b00000001 ;interrupts off, QC off, timeout off, SM disabled, enable master
	ldi XH, High(TWI0_MCTRLA)
	ldi XL, Low(TWI0_MCTRLA)
	st X, r16
	ret

writetwi:
	ldi r16, 0xFD
	ldi XH, High(TWI0_MDATA)
	ldi XL, Low(TWI0_MDATA)
	st X, r16

	ldi r16, 0x03
	ldi XH, High(TWI0_MCTRLB)
	ldi XL, Low(TWI0_MCTRLB)
	st X, r16
	inc r21
	
	ret