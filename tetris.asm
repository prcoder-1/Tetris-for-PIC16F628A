	list p=p16f628a
	errorlevel -302
	#include <p16f628a.inc>

	__CONFIG   _CP_OFF & _DATA_CP_OFF & _LVP_OFF & _BOREN_ON & _MCLRE_OFF & _PWRTE_ON & _WDT_OFF & _HS_OSC; & _INTRC_OSC_NOCLKOUT
; 20 Mhz crystal

#define VIDPORT PORTB
#define SYNCPORT PORTA

#define SYNCBIT	SYNCPORT, 0
#define VIDBIT VIDPORT, 7

#define KEYS_PORT PORTA
#define KEY_LEFT 2
#define KEY_RIGHT 3
#define KEY_ROTATE 4
#define KEY_DROP 5

#define KEY_LEFT_BIT KEYS_PORT, KEY_LEFT
#define KEY_RIGHT_BIT KEYS_PORT, KEY_RIGHT
#define KEY_ROTATE_BIT KEYS_PORT, KEY_ROTATE
#define KEY_DROP_BIT KEYS_PORT, KEY_DROP


#define STATE_CAN_PUT_BLOCK 0

MAX_BLOCK_X	equ	d'14'
START_BLOCK_X	equ	d'7'

; Variables
cblock	0x20
	d_ctr, d_ctr2, line_no, field, crc
	index, tmp_bits1, tmp_bits2, ch_line, ch_num
	block_no, block_x, block_y, block_rot
	p_block_x, p_block_y, p_block_rot, state, drop_ctr, key_ctr
	pf11, pf12, pf21, pf22, pf31, pf32, pf41, pf42
endc
VIDEOBUF	equ	0x3B	; 10 bytes
CHARBUF		equ	0x45	; 10 bytes
PLAYFIELD	equ	0x4F	; 48 bytes

prepare_video_byte MACRO i ; (3 mks)
	movf	CHARBUF+i, w	; (0.2 mks)
	movwf	index		; (0.2 mks)
 	bcf	STATUS, C	; (0.2 mks)
 	rlf	index, f	; (0.2 mks)
 	rlf	index, f	; (0.2 mks)
 	rlf	index, f	; (0.2 mks)
 	movf	ch_line, w	; (0.2 mks)
 	addwf	index, w	; (0.2 mks)
 	call	font		; (1.2 mks)
	movwf	VIDEOBUF+i	; (0.2 mks)
	ENDM

shift_video_byte MACRO i ; (1.8 mks)
	movf	VIDEOBUF+i, w	; (0.2 mks)
	movwf	VIDPORT		; (0.2 mks)
	rlf	VIDPORT,f	; (0.2 mks)
	rlf	VIDPORT,f	; (0.2 mks)
	rlf	VIDPORT,f	; (0.2 mks)
	rlf	VIDPORT,f	; (0.2 mks)
	rlf	VIDPORT,f	; (0.2 mks)
	rlf	VIDPORT,f	; (0.2 mks)
	rlf	VIDPORT,f	; (0.2 mks)
	ENDM

shift_pf_bit MACRO bits ; (1.4 mks)
	rlf	bits, f		; (0.2 mks)
	rrf	VIDPORT, f	; (0.2 mks)
	call	delay_1_0mks	; (1 mks)
	ENDM

	ORG     0x000		; reset vector

	bcf	STATUS, RP0	; switch to
	bcf	STATUS, RP1	; bank0
	movlw	(1 << CM2) | (1 << CM1) | (1 << CM0)
	movwf	CMCON		; disable comparators
	clrf	PORTA		; initialize PORTA
	clrf	PORTB		; initialize PORTB
	bsf	STATUS, RP0	; bank1
	movlw	(1 << KEY_DROP) | (1 << KEY_ROTATE) | (1 << KEY_RIGHT) | (1 << KEY_LEFT)
	movwf	TRISA		; set buttons as inputs, other as outputs
	clrf	TRISB		; set all pins on PORTB as outputs
	bcf	STATUS, RP0	; bank0

	movlw	CHARBUF
	movwf	FSR
	movlw	d'10'
	movwf	d_ctr
	clrf	index
fill_l:
	movf	index, w
	movwf	INDF
	incf	index, f
	incf	FSR, f
	decfsz	d_ctr, f
	goto	fill_l

; --------- fill playfield with initial values ---------
	movlw	PLAYFIELD	; pointer to playfield
	movwf	FSR

	movlw	d'23'		; playfield heigth - 1
	movwf	d_ctr
pf_fill_l:
	movlw	0x10
	movwf	INDF
	incf	FSR, f
	movlw	0x01
	movwf	INDF
	incf	FSR, f
	decfsz	d_ctr, f
	goto	pf_fill_l
	movlw	0x1F
	movwf	INDF
	incf	FSR, f
	movlw	0xFF
	movwf	INDF
	incf	FSR, f

	movlw	d'3'
	movwf	block_no
	movlw	START_BLOCK_X
	movwf	block_x
	movwf	p_block_x
	clrf	block_y
	clrf	p_block_y
	clrf	block_rot
	clrf	p_block_rot
	clrf	drop_ctr
	clrf	key_ctr
	clrf	state

	movlw	d'1'
	movwf	field
	bcf	VIDBIT
	bsf	SYNCBIT
main_l:
; -------------------- draw 30 black lines ------------------------
	movlw	d'29'		; (0.2 mks)
	movwf	line_no		; (0.2 mks)
main_l1:
	call	h_sync_pulse	; (12 mks)
	movlw	d'83'		; (0.2 mks)
	call	delay_qmks	; (51 mks)
	nop			; (0.2 mks)
	decfsz	line_no, f	; (0.2 mks)
	goto	main_l1		; (0.4 mks)
				; (0.2 mks) decfsz nop
	nop			; (0.2 mks)
	goto	$+1		; (0.4 mks)
	call	h_sync_pulse	; (12 mks)
	movlw	d'82'		; (0.2 mks)
	call	delay_qmks	; (50.4 mks)
	goto	$+1		; (0.4 mks)
; ---------- draw 8 lines of text + 1 black line -------------
	movlw	d'8'		; (0.2 mks)
	movwf	line_no		; (0.2 mks)
	clrf	ch_line		; (0.2 mks)
main_l2:
	call	draw_text_line	; (63.4 mks)
	decfsz	line_no, f	; (0.2 mks)
	goto	main_l2		; (0.4 mks)
				; (0.2 mks) decfsz nop
	nop			; (0.2 mks)
	goto	$+1		; (0.4 mks)
	call	h_sync_pulse	; (12 mks)
	call	calculate_block	; (51.4 mks)
	nop			; (0.2 mks)
	call	h_sync_pulse	; (12 mks)
	call	can_put_block	; (9.6 mks)
	btfsc	state, STATE_CAN_PUT_BLOCK ; (0.2 mks)
	goto	main_j1		; (0.4 mks)
				; (0.2 mks) btfsc nop
	movf	p_block_x, w	; (0.2 mks)
	movwf	block_x		; (0.2 mks)
	movf	p_block_rot, w	; (0.2 mks)
	movwf	block_rot	; (0.2 mks)
	call	delay_2_0mks	; (2 mks)
	call	delay_2_0mks	; (2 mks)
	call	delay_1_2mks	; (1.2 mks)
	goto	main_j2		; (0.4 mks)
main_j1:
	call	put_block	; (6.2 mks)
main_j2:
	movlw	d'55'		; (0.2 mks)
	call	delay_qmks	; (34.2 mks)
; -------- draw 210 lines of playfield + 1 black line ----------
	clrf	index		; (0.2 mks)
	clrf	d_ctr2		; (0.2 mks)
	movlw	d'210'		; (0.2 mks)
	movwf	line_no		; (0.2 mks)
main_l3:
	call	draw_playfiled_line ; (63.4 mks)
	decfsz	line_no, f	; (0.2 mks)
	goto	main_l3		; (0.4 mks)
				; (0.2 mks) decfsz nop
	nop			; (0.2 mks)
	goto	$+1		; (0.4 mks)
	call	h_sync_pulse	; (12 mks)

	btfsc	state, STATE_CAN_PUT_BLOCK ; (0.2 mks)
	goto	main_j3		; (0.4 mks)
				; (0.2 mks) btfsz nop
	call	delay_2_0mks	; (2 mks)
	call	delay_2_0mks	; (2 mks)
	call	delay_1_8mks	; (1.8 mks)
	goto	main_j4		; (0.4 mks)
main_j3:
	call	remove_block	; (6 mks)
main_j4:
	call	advance_step	; (2.4 mks)
	movlw	d'71'		; (0.2 mks)
	call	delay_qmks	; (43.8 mks)
	call	h_sync_pulse	; (12 mks)
	call	calculate_block	; (51.4 mks)
	nop			; (0.2 mks)
	call	h_sync_pulse	; (12 mks)
	call	can_put_block	; (9.6 mks)
	btfsc	state, STATE_CAN_PUT_BLOCK ; (0.2 mks)
	goto	main_j5		; (0.4 mks)
				; (0.2 mks) btfsc nop
	; new block
	movf	p_block_y, w	; (0.2 mks)
	movwf	block_y		; (0.2 mks)
	call	put_block	; (6.2 mks)

	movf	block_x, w	; (0.2 mks)
	call	crc_calc	; (4.6 mks)

	clrf	block_y		; (0.2 mks)
	movlw	START_BLOCK_X	; (0.2 mks)
	movwf	block_x		; (0.2 mks)

	movf	block_no, w	; (0.2 mks)
	call	crc_calc	; (4.6 mks)
	andlw	0x07		; (0.2 mks)
	movwf	block_no	; (0.2 mks)
	sublw	0x07		; (0.2 mks)
	btfsc	STATUS, Z	; (0.2 mks)
	bcf	block_no, 0	; (0.2 mks)

	clrf	block_rot	; (0.2 mks)

	goto	main_j6		; (0.4 mks)
main_j5:
	movlw	d'28'		; (0.2 mks)
	call	delay_qmks	; (18 mks)
main_j6:
	movf	block_x, w	; (0.2 mks)
	movwf	p_block_x	; (0.2 mks)
	movf	block_y, w	; (0.2 mks)
	movwf	p_block_y	; (0.2 mks)
	movf	block_rot, w	; (0.2 mks)
	movwf	p_block_rot	; (0.2 mks)
; @41.6
	call	check_keys	; (3.4 mks)
	movlw	d'28'		; (0.2 mks)
	call	delay_qmks	; (18 mks)

; ------------------ draw 52 black lines -----------------------
	movlw	d'51'		; (0.2 mks)
	movwf	line_no		; (0.2 mks)
main_l4:
	call	draw_black_line ; (63.4 mks)
	decfsz	line_no, f	; (0.2 mks)
	goto	main_l4		; (0.4 mks)
				; (0.2 mks) decfsz nop
	nop			; (0.2 mks)
	goto	$+1		; (0.4 mks)
	call	h_sync_pulse	; (12 mks)
	movlw	d'83'		; (0.2 mks)
	call	delay_qmks	; (51 mks)
	call	delay_0_8mks	; (0.8 mks)
; ----------------- VSync ---------------------
	bcf	SYNCBIT		; (0.2 mks) start sync pulse
	call	delay_1_4mks	; (1.4 mks)
	call	delay_0_8mks	; (0.8 mks)
	bsf	SYNCBIT		; (0.2 mks) stop sync pulse
	movlw	d'45'		; (0.2 mks)
	call	delay_qmks	; (28.2 mks)
	nop			; (0.2 mks)
; @ 31.2 mks
	movlw	d'5'		; (0.2 mks)
	btfsc	field, 0	; (0.2 mks + (0.2 mks))
	movlw	d'4'		; (0.2 mks)
	movwf	d_ctr2		; (0.2 mks)
v_sync_eq1_l:
	bcf	SYNCBIT		; (0.2 mks) start sync pulse
	call	delay_1_4mks	; (1.4 mks)
	call	delay_0_8mks	; (0.8 mks)
	bsf	SYNCBIT		; (0.2 mks) stop sync pulse
	movlw	d'44'		; (0.2 mks)
	call	delay_qmks	; (28.2 mks)
	goto	$+1		; (0.4 mks)
	decfsz	d_ctr2, f	; (0.2 mks)
	goto	v_sync_eq1_l	; (0.4 mks)
				; (0.2 mks) decfz nop
	nop			; (0.2 mks)
	bcf	SYNCBIT		; (0.2 mks) start sync pulse
	movlw	d'42'		; (0.2 mks)
	call	delay_qmks	; (26.4 mks)
	goto	$+1		; (0.4 mks)
	bsf	SYNCBIT		; (0.2 mks) stop sync pulse
	movlw	d'4'		; (0.2 mks)
	call	delay_qmks	; (3.6 mks)
	goto	$+1		; (0.4 mks)
	movlw	d'4'		; (0.2 mks)
	movwf	d_ctr2		; (0.2 mks)
v_sync_eq2_l:
	bcf	SYNCBIT		; (0.2 mks) start sync pulse
	movlw	d'42'		; (0.2 mks)
	call	delay_qmks	; (26.4 mks)
	goto	$+1		; (0.4 mks)
	bsf	SYNCBIT		; (0.2 mks) stop sync pulse
	movlw	d'4'		; (0.2 mks)
	call	delay_qmks	; (3.6 mks)
	nop			; (0.2 mks)
	decfsz	d_ctr2, f	; (0.2 mks)
	goto	v_sync_eq2_l	; (0.4 mks)
				; (0.2 mks) decfz nop
	nop			; (0.2 mks)
	bcf	SYNCBIT		; (0.2 mks) start sync pulse
	call	delay_1_4mks	; (1.4 mks)
	call	delay_0_8mks	; (0.8 mks)
	bsf	SYNCBIT		; (0.2 mks) stop sync pulse
	movlw	d'45'		; (0.2 mks)
	call	delay_qmks	; (28.2 mks)
	nop			; (0.2 mks)
	movlw	d'4'		; (0.2 mks)
	btfsc	field, 0	; (0.2 mks + (0.2 mks))
	movlw	d'3'		; (0.2 mks)
	movwf	d_ctr2		; (0.2 mks)
v_sync_eq3_l:
	bcf	SYNCBIT		; (0.2 mks) start sync pulse
	call	delay_1_4mks	; (1.4 mks)
	call	delay_0_8mks	; (0.8 mks)
	bsf	SYNCBIT		; (0.2 mks) stop sync pulse
	movlw	d'45'		; (0.2 mks)
	call	delay_qmks	; (28.2 mks)
	goto	$+1		; (0.4 mks)
	decfsz	d_ctr2, f	; (0.2 mks)
	goto	v_sync_eq3_l	; (0.4 mks)
				; (0.2 mks) decfz nop
;	incf	field, f	; (0.2 mks) interlaced
	nop			; (0.2 mks) noninterlaced
	call	h_sync_pulse	; (12 mks)
	movlw	d'83'		; (0.2 mks)
	call	delay_qmks	; (51 mks)
; ----------------- VSync ---------------------
	goto	main_l		; (0.4 mks)

; ------------ draw text line (63.4 mks) -----------
draw_text_line:		; (0.4 mks) call
	call	h_sync_pulse	; (12 mks)
	movlw	HIGH font	; (0.2 mks)
	movwf	PCLATH		; (0.2 mks)
	prepare_video_byte 0	; (3 mks)
	prepare_video_byte 1	; (3 mks)
	prepare_video_byte 2	; (3 mks)
	prepare_video_byte 3	; (3 mks)
	prepare_video_byte 4	; (3 mks)
	prepare_video_byte 5	; (3 mks)
	prepare_video_byte 6	; (3 mks)
	prepare_video_byte 7	; (3 mks)
	prepare_video_byte 8	; (3 mks)
	prepare_video_byte 9	; (3 mks)
; @42.4 mks
	shift_video_byte 0	; (1.8 mks)
	shift_video_byte 1	; (1.8 mks)
	shift_video_byte 2	; (1.8 mks)
	shift_video_byte 3	; (1.8 mks)
	shift_video_byte 4	; (1.8 mks)
	shift_video_byte 5	; (1.8 mks)
	shift_video_byte 6	; (1.8 mks)
	shift_video_byte 7	; (1.8 mks)
	shift_video_byte 8	; (1.8 mks)
	shift_video_byte 9	; (1.8 mks)
; @60.4
	incf	ch_line, f	; (0.2 mks)
	call	delay_1_6mks	; (1.6 mks)
	return			; (0.4 mks)

; ------------ draw black line (63.4 mks) -----------
draw_black_line:
	call	h_sync_pulse	; (12 mks)
	movlw	d'82'		; (0.2 mks)
	call	delay_qmks	; (50.4 mks)
	return			; (0.4 mks)

; ------------ draw playfield line (63.4 mks) -----------
draw_playfiled_line:
	call	h_sync_pulse	; (12 mks)

	movlw	d'10'		; (0.2 mks)
	subwf	d_ctr2, w	; (0.2 mks)
	btfss	STATUS, Z	; (0.2 mks)
	goto	draw_playfield_line_j1 ; (0.4 mks)
	incf	index, f	; (0.2 mks)
	incf	index, f	; (0.2 mks)
	clrf	d_ctr2		; (0.2 mks)
	goto	draw_playfield_line_j2 ; (0.4 mks)
draw_playfield_line_j1:
	call	delay_0_8mks	; (0.8 mks)
draw_playfield_line_j2:
	incf	d_ctr2, f	; (0.2 mks)

	movlw	PLAYFIELD+3*2	; (0.2 mks)
	addwf	index, w	; (0.2 mks)
	movwf	FSR		; (0.2 mks)
	movf	INDF, w		; (0.2 mks)
	movwf	tmp_bits1	; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	movf	INDF, w		; (0.2 mks)
	movwf	tmp_bits2	; (0.2 mks)

	shift_pf_bit tmp_bits1 ; (1.4 mks) bit7
	shift_pf_bit tmp_bits1 ; (1.4 mks) bit6
	shift_pf_bit tmp_bits1 ; (1.4 mks) bit5
	shift_pf_bit tmp_bits1 ; (1.4 mks) bit4
	shift_pf_bit tmp_bits1 ; (1.4 mks) bit3
	shift_pf_bit tmp_bits1 ; (1.4 mks) bit2
	shift_pf_bit tmp_bits1 ; (1.4 mks) bit1
	shift_pf_bit tmp_bits1 ; (1.4 mks) bit0
	shift_pf_bit tmp_bits2 ; (1.4 mks) bit7
	shift_pf_bit tmp_bits2 ; (1.4 mks) bit6
	shift_pf_bit tmp_bits2 ; (1.4 mks) bit5
	shift_pf_bit tmp_bits2 ; (1.4 mks) bit4
	shift_pf_bit tmp_bits2 ; (1.4 mks) bit3
	shift_pf_bit tmp_bits2 ; (1.4 mks) bit2
	shift_pf_bit tmp_bits2 ; (1.4 mks) bit1
	shift_pf_bit tmp_bits2 ; (1.4 mks) bit0
	nop			; (0.2 mks)
	bcf	VIDBIT		; (0.2 mks)

	movlw	d'38'		; (0.2 mks)
	call	delay_qmks	; (24 mks)
	nop			; (0.2 mks)
	return			; (0.4 mks)

; -------------- hsync pulse (12 mks) -----------------
h_sync_pulse:			; (0.4 mks) call
	call	delay_1_0mks	; (1.0 mks)
	bcf	SYNCBIT		; (0.2 mks) start sync pulse
	movlw	d'5'		; (0.2 mks)
	call	delay_qmks	; (4.2 mks)
	nop			; (0.2 mks)
	bsf	SYNCBIT		; (0.2 mks) stop sync pulse
	movlw	d'6'		; (0.2 mks)
	call	delay_qmks	; (4.8 mks)
	nop			; (0.2 mks)
	return			; (0.4 mks)

; ------------------------------------------------------
delay_2_0mks:	nop		; (0.2 mks)
delay_1_8mks:	nop		; (0.2 mks)
delay_1_6mks:	nop		; (0.2 mks)
delay_1_4mks:	nop		; (0.2 mks)
delay_1_2mks:	nop		; (0.2 mks)
delay_1_0mks:	nop		; (0.2 mks)
delay_0_8mks:			; (0.4 mks) call
		return		; (0.4 mks)

; wait 1.2 mks + W * 0.6 mks = 0.6 * (W + 2) mks
; W = t / 0.6 - 2;
; uses 'd_ctr'
delay_qmks:			; (0.4 mks) call
	movwf	d_ctr		; (0.2 mks)
delay_qmks_l:
	decfsz	d_ctr, f	; (0.2 mks)
	goto	delay_qmks_l	; (0.4 mks)
				; (0.2 mks) decfsz nop
	return			; (0.4 mks)

; --- Calculate block in pf registers (51.4 mks)---
; input: block_no, block_x, block_rot
; output: block bits in {{pf11, pf12}, {pf21, pf22}, {pf31, pf32}, {pf41, pf42}}
calculate_block:
	movlw	HIGH block	; (0.2 mks)
	movwf	PCLATH		; (0.2 mks)
	movf	block_no, w	; (0.2 mks)
	movwf	index		; (0.2 mks)
	bcf	STATUS, C	; (0.2 mks)
	rlf	index, f	; (0.2 mks)
	rlf	index, f	; (0.2 mks)
	rlf	index, f	; (0.2 mks)
	movf	block_rot, w	; (0.2 mks)
	addwf	index, f	; (0.2 mks)
	addwf	index, f	; (0.2 mks)

	movf	index, w	; (0.2 mks)
	call	block		; (1.2 mks)
	movwf	pf11		; (0.2 mks)
	movwf	pf21		; (0.2 mks)
	swapf	pf21, f		; (0.2 mks)
	movlw	0xF0		; (0.2 mks)
	andwf	pf11, f		; (0.2 mks)
	andwf	pf21, f		; (0.2 mks)
	clrf	pf12		; (0.2 mks)
	clrf	pf22		; (0.2 mks)
	incf	index, w	; (0.2 mks)
	call	block		; (1.2 mks)
	movwf	pf31		; (0.2 mks)
	movwf	pf41		; (0.2 mks)
	swapf	pf41, f		; (0.2 mks)
	movlw	0xF0		; (0.2 mks)
	andwf	pf31, f		; (0.2 mks)
	andwf	pf41, f		; (0.2 mks)
	clrf	pf32		; (0.2 mks)
	clrf	pf42		; (0.2 mks)

	movf	block_x, w	; (0.2 mks)
	movwf	d_ctr		; (0.2 mks)
; @8.8 mks
calculate_block_l1:	; (3 mks) * block_x
	bcf	STATUS, C	; (0.2 mks)
	rrf	pf11, f		; (0.2 mks)
	rrf	pf12, f		; (0.2 mks)
	bcf	STATUS, C	; (0.2 mks)
	rrf	pf21, f		; (0.2 mks)
	rrf	pf22, f		; (0.2 mks)
	bcf	STATUS, C	; (0.2 mks)
	rrf	pf31, f		; (0.2 mks)
	rrf	pf32, f		; (0.2 mks)
	bcf	STATUS, C	; (0.2 mks)
	rrf	pf41, f		; (0.2 mks)
	rrf	pf42, f		; (0.2 mks)
	decfsz	d_ctr, f	; (0.2 mks)
	goto	calculate_block_l1 ; (0.4 mks)
				; (0.2 mks) decfsz nop
	; --- time compensation loop ---
	movlw	MAX_BLOCK_X	; (0.2 mks)
	movwf	d_ctr		; (0.2 mks)
	movf	block_x, w	; (0.2 mks)
	subwf	d_ctr, f	; (0.2 mks)
calculate_block_l2:	; (3 mks) * (MAX_BLOCK_X - block_x)
	call	delay_2_0mks	; (2.0 mks)
	goto	$+1		; (0.4 mks)
	decfsz	d_ctr, f	; (0.2 mks)
	goto	calculate_block_l2 ; (0.4 mks)
				; (0.2 mks) decfsz nop
	return			; (0.4 mks)

; --- Can put block in playfield ? (9.8 mks)---
can_put_block:			; (0.4 mks) call
	bcf	state, STATE_CAN_PUT_BLOCK ; (0.2 mks)
	bcf	STATUS, C	; (0.2 mks)
	rlf	block_y, w	; (0.2 mks)
	addlw	PLAYFIELD	; (0.2 mks)
	movwf	FSR		; (0.2 mks)
	movf	pf11, w		; (0.2 mks)
	andwf	INDF, w		; (0.2 mks)
	btfss	STATUS, Z	; (0.2 mks)
	goto	can_put_block_ret01 ; (0.4 mks)
				; (0.2 mks) btfsc nop
	incf	FSR, f		; (0.2 mks)
	movf	pf12, w		; (0.2 mks)
	andwf	INDF, w		; (0.2 mks)
	btfss	STATUS, Z	; (0.2 mks)
	goto	can_put_block_ret02 ; (0.4 mks)
				; (0.2 mks) btfsc nop
	incf	FSR, f		; (0.2 mks)
	movf	pf21, w		; (0.2 mks)
	andwf	INDF, w		; (0.2 mks)
	btfss	STATUS, Z	; (0.2 mks)
	goto	can_put_block_ret03 ; (0.4 mks)
				; (0.2 mks) btfsc nop
	incf	FSR, f		; (0.2 mks)
	movf	pf22, w		; (0.2 mks)
	andwf	INDF, w		; (0.2 mks)
	btfss	STATUS, Z	; (0.2 mks)
	goto	can_put_block_ret04 ; (0.4 mks)
				; (0.2 mks) btfsc nop
	incf	FSR, f		; (0.2 mks)
	movf	pf31, w		; (0.2 mks)
	andwf	INDF, w		; (0.2 mks)
	btfss	STATUS, Z	; (0.2 mks)
	goto	can_put_block_ret05 ; (0.4 mks)
				; (0.2 mks) btfsc nop
	incf	FSR, f		; (0.2 mks)
	movf	pf32, w		; (0.2 mks)
	andwf	INDF, w		; (0.2 mks)
	btfss	STATUS, Z	; (0.2 mks)
	goto	can_put_block_ret06 ; (0.4 mks)
				; (0.2 mks) btfsc nop
	incf	FSR, f		; (0.2 mks)
	movf	pf41, w		; (0.2 mks)
	andwf	INDF, w		; (0.2 mks)
	btfss	STATUS, Z	; (0.2 mks)
	goto	can_put_block_ret07 ; (0.4 mks)
				; (0.2 mks) btfsc nop
	incf	FSR, f		; (0.2 mks)
	movf	pf42, w		; (0.2 mks)
	andwf	INDF, w		; (0.2 mks)
	btfss	STATUS, Z	; (0.2 mks)
	goto	can_put_block_ret08 ; (0.4 mks)
				; (0.2 mks) btfsc nop
	bsf	state, STATE_CAN_PUT_BLOCK ; (0.2 mks)
	return			; (0.4 mks)

can_put_block_ret01:
	call	delay_1_0mks	; (1 mks)
can_put_block_ret02:
	call	delay_1_0mks	; (1 mks)
can_put_block_ret03:
	call	delay_1_0mks	; (1 mks)
can_put_block_ret04:
	call	delay_1_0mks	; (1 mks)
can_put_block_ret05:
	call	delay_1_0mks	; (1 mks)
can_put_block_ret06:
	call	delay_1_0mks	; (1 mks)
can_put_block_ret07:
	call	delay_1_0mks	; (1 mks)
can_put_block_ret08:
	return			; (0.4 mks)

; --- Put block in playfield (6.2 mks) ---
; input: block_no, block_x, block_y, block_rot, block bits in pf registers
put_block:			; (0.4 mks) call
	bcf	STATUS, C	; (0.2 mks)
	rlf	block_y, w	; (0.2 mks)
	addlw	PLAYFIELD	; (0.2 mks)
	movwf	FSR		; (0.2 mks)
	movf	pf11, w		; (0.2 mks)
	iorwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	movf	pf12, w		; (0.2 mks)
	iorwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	movf	pf21, w		; (0.2 mks)
	iorwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	movf	pf22, w		; (0.2 mks)
	iorwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	movf	pf31, w		; (0.2 mks)
	iorwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	movf	pf32, w		; (0.2 mks)
	iorwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	movf	pf41, w		; (0.2 mks)
	iorwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	movf	pf42, w		; (0.2 mks)
	iorwf	INDF, f		; (0.2 mks)
	return			; (0.4 mks)

; --- Remove block from playfield (6.2 mks)---
; input: block_no, block_x, block_y, block_rot, block bits in pf registers
remove_block:			; (0.4 mks) call
	bcf	STATUS, C	; (0.2 mks)
	rlf	block_y, w	; (0.2 mks)
	addlw	PLAYFIELD	; (0.2 mks)
	movwf	FSR		; (0.2 mks)
	comf	pf11, w		; (0.2 mks)
	andwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	comf	pf12, w		; (0.2 mks)
	andwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	comf	pf21, w		; (0.2 mks)
	andwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	comf	pf22, w		; (0.2 mks)
	andwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	comf	pf31, w		; (0.2 mks)
	andwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	comf	pf32, w		; (0.2 mks)
	andwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	comf	pf41, w		; (0.2 mks)
	andwf	INDF, f		; (0.2 mks)
	incf	FSR, f		; (0.2 mks)
	comf	pf42, w		; (0.2 mks)
	andwf	INDF, f		; (0.2 mks)
	return			; (0.4 mks)

; --- advance game step (2.4 mks) ---
advance_step:			; (0.4 mks) call
	incf	drop_ctr, f	; (0.2 mks)
	movlw	d'25'		; (0.2 mks)
	subwf	drop_ctr, w	; (0.2 mks)
	btfsc	STATUS, Z	; (0.2 mks)
	goto	advance_step_j1	; (0.4 mks)
				; (0.2 mks) btfsc nop
	btfss	KEY_DROP_BIT	; (0.2 mks)
	incf	block_y, f	; (0.2 mks)
				; (0.2 mks) btfss nop
	goto	advance_step_j2	; (0.4 mks)
advance_step_j1:
	clrf	drop_ctr	; (0.2 mks)
	incf	block_y, f	; (0.2 mks)
advance_step_j2:
	return			; (0.4 mks)

; --- check if any keys pressed (3.4 mks) ---
check_keys:			; (0.4 mks) call
	movlw	d'3'		; (0.2 mks)
	subwf	key_ctr, w	; (0.2 mks)
	btfss	STATUS, Z	; (0.2 mks)
	goto	check_keys_j1	; (0.4 mks)
				; (0.2 mks) btfsc nop
	clrf	key_ctr		; (0.2 mks)
	btfss	KEY_RIGHT_BIT	; (0.2 mks)
	incf	block_x, f	; (0.2 mks)
	btfss	KEY_LEFT_BIT	; (0.2 mks)
	decf	block_x, f	; (0.2 mks)
	btfss	KEY_ROTATE_BIT	; (0.2 mks)
	incf	block_rot, f	; (0.2 mks)

	movlw	0x3		; (0.2 mks)
	andwf	block_rot, f	; (0.2 mks)
	return			; (0.4 mks)

check_keys_j1:
	incf	key_ctr, f	; (0.2 mks)
	call	delay_1_4mks	; (1.4 mks)
	return			; (0.4 mks)


; --- calculate cumulative CRC-8 (4.6 mks) ---
crc_calc:			; (0.4 mks) call
	xorwf	crc, f		; (0.2 mks)
	clrw			; (0.2 mks)
	btfsc	crc, 0		; (0.2 mks)
	xorlw	0x5e		; (0.2 mks)
	btfsc	crc, 1		; (0.2 mks)
	xorlw	0xbc		; (0.2 mks)
	btfsc	crc, 2		; (0.2 mks)
	xorlw	0x61		; (0.2 mks)
	btfsc	crc, 3		; (0.2 mks)
	xorlw	0xc2		; (0.2 mks)
	btfsc	crc, 4		; (0.2 mks)
	xorlw	0x9d		; (0.2 mks)
	btfsc	crc, 5		; (0.2 mks)
	xorlw	0x23		; (0.2 mks)
	btfsc	crc, 6		; (0.2 mks)
	xorlw	0x46		; (0.2 mks)
	btfsc	crc, 7		; (0.2 mks)
	xorlw	0x8c		; (0.2 mks)
	movwf	crc		; (0.2 mks)
	return			; (0.4 mks)


	org	0x3C7
block:	; 0.4 mks (call) + 0.4 mks (addwf) + 0.4 mks (retlw) = 1.2 mks
	addwf	PCL, f		; (0.2 mks)
	DT	0x06, 0x60, 0x06, 0x60, 0x06, 0x60, 0x06, 0x60	; O
	DT	0x0F, 0x00, 0x22, 0x22, 0x0F, 0x00, 0x22, 0x22	; I
	DT	0x03, 0x60, 0x23, 0x10, 0x03, 0x60, 0x23, 0x10	; S
	DT	0x06, 0x30, 0x13, 0x20, 0x06, 0x30, 0x13, 0x20	; Z
	DT	0x07, 0x40, 0x22, 0x30, 0x17, 0x00, 0x62, 0x20	; L
	DT	0x07, 0x10, 0x32, 0x20, 0x47, 0x00, 0x22, 0x60	; J
	DT	0x07, 0x20, 0x23, 0x20, 0x27, 0x00, 0x26, 0x20	; T

	org	0x400
; in: W = (character << 3) + lineno
; out: W = bits
font:	; 0.4 mks (call) + 0.4 mks (addwf) + 0.4 mks (retlw) = 1.2 mks
	addwf	PCL, f		; (0.2 mks)
	DT	b'01111100'	; (0.4 mks) 1	"0"
	DT	b'11000110'	; (0.4 mks) 2
	DT	b'11001110'	; (0.4 mks) 3
	DT	b'11010110'	; (0.4 mks) 4
	DT	b'11010110'	; (0.4 mks) 5
	DT	b'11100110'	; (0.4 mks) 6
	DT	b'11000110'	; (0.4 mks) 7
	DT	b'01111100'	; (0.4 mks) 8

	DT	b'00011000'	; (0.4 mks) 1	"1"
	DT	b'00111000'	; (0.4 mks) 2
	DT	b'00011000'	; (0.4 mks) 3
	DT	b'00011000'	; (0.4 mks) 4
	DT	b'00011000'	; (0.4 mks) 5
	DT	b'00011000'	; (0.4 mks) 6
	DT	b'00011000'	; (0.4 mks) 7
	DT	b'00111100'	; (0.4 mks) 8

	DT	b'01111100'	; (0.4 mks) 1	"2"
	DT	b'11000110'	; (0.4 mks) 2
	DT	b'00000110'	; (0.4 mks) 3
	DT	b'00001100'	; (0.4 mks) 4
	DT	b'00011000'	; (0.4 mks) 5
	DT	b'00110000'	; (0.4 mks) 6
	DT	b'01100000'	; (0.4 mks) 7
	DT	b'11111110'	; (0.4 mks) 8

	DT	b'01111100'	; (0.4 mks) 1	"3"
	DT	b'11000110'	; (0.4 mks) 2
	DT	b'00000110'	; (0.4 mks) 3
	DT	b'00011100'	; (0.4 mks) 4
	DT	b'00000110'	; (0.4 mks) 5
	DT	b'00000110'	; (0.4 mks) 6
	DT	b'11000110'	; (0.4 mks) 7
	DT	b'01111100'	; (0.4 mks) 8

	DT	b'00001110'	; (0.4 mks) 1	"4"
	DT	b'00011110'	; (0.4 mks) 2
	DT	b'00110110'	; (0.4 mks) 3
	DT	b'01100110'	; (0.4 mks) 4
	DT	b'11000110'	; (0.4 mks) 5
	DT	b'11111110'	; (0.4 mks) 6
	DT	b'00000110'	; (0.4 mks) 7
	DT	b'00000110'	; (0.4 mks) 8

	DT	b'11111110'	; (0.4 mks) 1	"5"
	DT	b'11000000'	; (0.4 mks) 2
	DT	b'11000000'	; (0.4 mks) 3
	DT	b'11111100'	; (0.4 mks) 4
	DT	b'00000110'	; (0.4 mks) 5
	DT	b'00000110'	; (0.4 mks) 6
	DT	b'11000110'	; (0.4 mks) 7
	DT	b'01111100'	; (0.4 mks) 8

	DT	b'01111100'	; (0.4 mks) 1	"6"
	DT	b'11000110'	; (0.4 mks) 2
	DT	b'11000000'	; (0.4 mks) 3
	DT	b'11111100'	; (0.4 mks) 4
	DT	b'11000110'	; (0.4 mks) 5
	DT	b'11000110'	; (0.4 mks) 6
	DT	b'11000110'	; (0.4 mks) 7
	DT	b'01111100'	; (0.4 mks) 8

	DT	b'11111110'	; (0.4 mks) 1	"7"
	DT	b'11000110'	; (0.4 mks) 2
	DT	b'00000110'	; (0.4 mks) 3
	DT	b'00001100'	; (0.4 mks) 4
	DT	b'00011000'	; (0.4 mks) 5
	DT	b'00110000'	; (0.4 mks) 6
	DT	b'00110000'	; (0.4 mks) 7
	DT	b'00110000'	; (0.4 mks) 8

	DT	b'01111100'	; (0.4 mks) 1	"8"
	DT	b'11000110'	; (0.4 mks) 2
	DT	b'11000110'	; (0.4 mks) 3
	DT	b'01111100'	; (0.4 mks) 4
	DT	b'11000110'	; (0.4 mks) 5
	DT	b'11000110'	; (0.4 mks) 6
	DT	b'11000110'	; (0.4 mks) 7
	DT	b'01111100'	; (0.4 mks) 8

	DT	b'01111100'	; (0.4 mks) 1	"9"
	DT	b'11000110'	; (0.4 mks) 2
	DT	b'11000110'	; (0.4 mks) 3
	DT	b'01111110'	; (0.4 mks) 4
	DT	b'00000110'	; (0.4 mks) 5
	DT	b'00000110'	; (0.4 mks) 6
	DT	b'11000110'	; (0.4 mks) 7
	DT	b'01111100'	; (0.4 mks) 8

	DT	b'00111000'	; (0.4 mks) 1	"A"
	DT	b'01101100'	; (0.4 mks) 2
	DT	b'11000110'	; (0.4 mks) 3
	DT	b'11000110'	; (0.4 mks) 4
	DT	b'11111110'	; (0.4 mks) 5
	DT	b'11000110'	; (0.4 mks) 6
	DT	b'11000110'	; (0.4 mks) 7
	DT	b'11000110'	; (0.4 mks) 8

	END
