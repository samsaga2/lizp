(in-package #:cl-z80)

;; special funcs
(definst (label keyw name rest body)
  (set-label name (page-address))
  (push-namespace name)
  (asm-insts body)
  (pop-namespace))

(definst (equ keyw name num n)
  (set-label name n))

(definst (db rest lst)
  (dolist (i lst)
    (cond ((numberp i) (emit i))
          ((stringp i) (emit-string i))
          (t (format nil "unknown value in db ~a~%" i)))))

(definst (dw rest lst)
  (loop for i in lst append
       (apply #'emit
              (if (numberp i)
                  (list (low-word i) (high-word i))
                  (list (make-forward-low-word i)
                        (make-forward-high-word i))))))

(definst (loop rest lst)
  (let ((lbl (genlabel)))
    (asm-inst
     `(label ,lbl
             ,@lst
             (djnz ,lbl)))))

(definst (save (rest regs) rest lst)
  (asm-insts
   `(,@(mapcar (lambda (i) (list :push i)) regs)
     ,@lst
     ,@(mapcar (lambda (i) (list :pop i)) (reverse regs)))))

(definst (cond rest lst)
  (loop for i in lst do
       (asm-insts `((cp ,(car i))
                    (jp z,(cadr i))))))

(definst (incbin rest lst)
  (loop for i in lst do
       (with-open-file (stream i
                               :direction :input
                               :element-type 'unsigned-byte)
         (loop for byte = (read-byte stream nil) while byte do
              (emit byte)))))

(definst (unless reg reg rest lst)
  (let ((lbl (genlabel)))
    (asm-insts `((jr ,reg ,lbl)
                 ,@lst
                 (label ,lbl)))))

(definst (loop-while reg reg rest lst)
  (let ((lbl (genlabel)))
    (asm-insts `((label ,lbl)
                 ,@lst
                 (jr ,reg ,lbl)))))

(definst (loop-forever rest lst)
  (let ((lbl (genlabel)))
    (asm-insts `((label ,lbl)
                 ,@lst
                 (jr ,lbl)))))

(definst (with-di rest lst)
  (asm-insts `((di)
               ,@lst
               (ei))))

(definst (ld bc ix)
  (asm (push ix) (pop bc)))

(definst (ld bc iy)
  (asm (push iy) (pop bc)))

(definst (ld hl ix)
  (asm (push ix) (pop hl)))

(definst (ld hl iy)
  (asm (push iy) (pop hl)))

(definst (ld de ix)
  (asm (push ix) (pop de)))

(definst (ld de iy)
  (asm (push iy) (pop de)))

(definst (mul hl num number)
  (let ((pwr (log number 2)))
    (if (= pwr (floor pwr))
        (dotimes (i (floor pwr))
          (asm (add hl hl)))
        (format t "mult hl ~a is not supported" number))))

(definst (repeat num number rest lst)
  (dotimes (i number)
    (asm-insts lst)))

(definst (enum rest lst)
  (labels ((enum-index (lst index)
             (unless (null lst)
               (let ((hd (car lst))
                     (tl (cdr lst)))
                 (when (numberp (car tl))
                   (setq index (car tl))
                   (setq tl (cdr tl)))
                 (set-label hd index)
                 (enum-index tl (1+ index))))))
    (enum-index lst 0)))

(definst (struct rest lst)
  (let ((size 0))
    (labels ((struct (lst)
               (unless (null lst)
                 (let ((hd (car lst))
                       (tl (cadr lst)))
                   (set-label hd tl)
                   (incf size tl)
                   (struct (cddr lst))))))
      (struct lst)
      (set-label :size size))))


;; z80 insts
(defun bb (n)
  (if (numberp n)
      (byte-two-complement n)
      (make-forward-byte n)))

(defun wl (n)
  (if (numberp n)
      (low-word (word-two-complement n))
      (make-forward-low-word n)))

(defun wh (n)
  (if (numberp n)
      (high-word (word-two-complement n))
      (make-forward-high-word n)))

(defun ri (n)
  (if (numberp n)
      (byte-two-complement (- n (page-address) 2))
      (make-forward-index n)))

;; http//nemesis.lonestar.org/computers/tandy/software/apps/m4/qd/opcodes.html 
;; 8 bit transfer instructions
(definst (ld (bc) a) (emit #x02))
(definst (ld (de) a) (emit #x12))
(definst (ld (hl) a) (emit #x77))
(definst (ld (hl) b) (emit #x70))
(definst (ld (hl) num n) (emit #x36 (bb n)))
(definst (ld (hl) c) (emit #x71))
(definst (ld (hl) d) (emit #x72))
(definst (ld (hl) e) (emit #x73))
(definst (ld (hl) h) (emit #x74))
(definst (ld (hl) l) (emit #x75))
(definst (ld (ix num i) a) (emit #xdd #x77 (bb i)))
(definst (ld (ix num i) b) (emit #xdd #x70 (bb i)))
(definst (ld (ix num i) num b) (emit #xdd #x36 (bb i) (bb b))) ; #x36=#x76
(definst (ld (ix num i) c) (emit #xdd #x71 (bb i)))
(definst (ld (ix num i) d) (emit #xdd #x72 (bb i)))
(definst (ld (ix num i) e) (emit #xdd #x73 (bb i)))
(definst (ld (ix num i) h) (emit #xdd #x74 (bb i)))
(definst (ld (ix num i) l) (emit #xdd #x75 (bb i)))
(definst (ld (iy num i) a) (emit #xfd #x77 (bb i)))
(definst (ld (iy num i) b) (emit #xfd #x70 (bb i)))
(definst (ld (iy num i) num b) (emit #xfd #x36 (bb i) (bb b))) ; #x36=#x76
(definst (ld (iy num i) c) (emit #xfd #x71 (bb i)))
(definst (ld (iy num i) d) (emit #xfd #x72 (bb i)))
(definst (ld (iy num i) e) (emit #xfd #x73 (bb i)))
(definst (ld (iy num i) h) (emit #xfd #x74 (bb i)))
(definst (ld (iy num i) l) (emit #xfd #x75 (bb i)))
(definst (ld (num w) a) (emit #x32 (wl w) (wh w)))
(definst (ld a (bc)) (emit #x0a))
(definst (ld a (de)) (emit #x1a))
(definst (ld a (hl)) (emit #x7e))
(definst (ld a (ix num i)) (emit #xdd #x7e (bb i)))
(definst (ld a (iy num i)) (emit #xfd #x7e (bb i)))
(definst (ld a (num w)) (emit #x3a (wl w) (wh w)))
(definst (ld a a) (emit #x7f))
(definst (ld a b) (emit #x78))
(definst (ld a num b) (emit #x3e (bb b)))
(definst (ld a c) (emit #x79))
(definst (ld a d) (emit #x7a))
(definst (ld a e) (emit #x7b))
(definst (ld a h) (emit #x7c))
(definst (ld a l) (emit #x7d))
(definst (ld b (hl)) (emit #x46))
(definst (ld b (ix num i)) (emit #xdd #x46 (bb i)))
(definst (ld b (iy num i)) (emit #xfd #x46 (bb i)))
(definst (ld b a) (emit #x47))
(definst (ld b b) (emit #x40))
(definst (ld b num b) (emit #x06 (bb b)))
(definst (ld b c) (emit #x41))
(definst (ld b d) (emit #x42))
(definst (ld b e) (emit #x43))
(definst (ld b h) (emit #x44))
(definst (ld b l) (emit #x45))
(definst (ld c (hl)) (emit #x4e))
(definst (ld c (ix num i)) (emit #xdd #x4e (bb i)))
(definst (ld c (iy num i)) (emit #xfd #x4e (bb i)))
(definst (ld c a) (emit #x4f))
(definst (ld c b) (emit #x48))
(definst (ld c num b) (emit #x0e (bb b)))
(definst (ld c c) (emit #x49))
(definst (ld c d) (emit #x4a))
(definst (ld c e) (emit #x4b))
(definst (ld c h) (emit #x4c))
(definst (ld c l) (emit #x4d))
(definst (ld d (hl)) (emit #x56))
(definst (ld d (ix num i)) (emit #xdd #x56 (bb i)))
(definst (ld d (iy num i)) (emit #xfd #x56 (bb i)))
(definst (ld d a) (emit #x57))
(definst (ld d b) (emit #x50))
(definst (ld d num b) (emit #x16 (bb b)))
(definst (ld d c) (emit #x51))
(definst (ld d d) (emit #x52))
(definst (ld d e) (emit #x53))
(definst (ld d h) (emit #x54))
(definst (ld d l) (emit #x55))
(definst (ld e (hl)) (emit #x5e))
(definst (ld e (ix num i)) (emit #xdd #x5e (bb i)))
(definst (ld e (iy num i)) (emit #xfd #x5e (bb i)))
(definst (ld e a) (emit #x5f))
(definst (ld e b) (emit #x58))
(definst (ld e num b) (emit #x1e (bb b)))
(definst (ld e c) (emit #x59))
(definst (ld e d) (emit #x5a))
(definst (ld e e) (emit #x5b))
(definst (ld e h) (emit #x5c))
(definst (ld e l) (emit #x5d))
(definst (ld h (hl)) (emit #x66))
(definst (ld h (ix num i)) (emit #xdd #x66 (bb i)))
(definst (ld h (iy num i)) (emit #xfd #x66 (bb i)))
(definst (ld h a) (emit #x67))
(definst (ld h b) (emit #x60))
(definst (ld h num b) (emit #x26 (bb b)))
(definst (ld h c) (emit #x61))
(definst (ld h d) (emit #x62))
(definst (ld h e) (emit #x63))
(definst (ld h h) (emit #x64))
(definst (ld h l) (emit #x65))
(definst (ld l (hl)) (emit #x6e))
(definst (ld l (ix num i)) (emit #xdd #x6e (bb i)))
(definst (ld l (iy num i)) (emit #xfd #x6e (bb i)))
(definst (ld l a) (emit #x6f))
(definst (ld l b) (emit #x68))
(definst (ld l num b) (emit #x2e (bb b)))
(definst (ld l c) (emit #x69))
(definst (ld l d) (emit #x6a))
(definst (ld l e) (emit #x6b))
(definst (ld l h) (emit #x6c))
(definst (ld l l) (emit #x6d))

;; 16 bit transfer instructions
(definst (ld bc num w) (emit #x01 (wl w) (wh w)))
(definst (ld de num w) (emit #x11 (wl w) (wh w)))
(definst (ld hl num w) (emit #x21 (wl w) (wh w)))
(definst (ld sp num w) (emit #x31 (wl w) (wh w)))
(definst (ld ix num w) (emit #xdd #x21 (wl w) (wh w)))
(definst (ld iy num w) (emit #xfd #x21 (wl w) (wh w)))
(definst (ld hl (num w)) (emit #x2a (wl w) (wh w)))
(definst (ld bc (num w)) (emit #xed #x4b (wl w) (wh w)))
(definst (ld de (num w)) (emit #xed #x5b (wl w) (wh w)))
;; (definst (ld hl (num w)) (emit #xed #x6b (wl w) (wh w)))
(definst (ld sp (num w)) (emit #xed #x7b (wl w) (wh w)))
(definst (ld ix (num w)) (emit #xdd #x2a (wl w) (wh w)))
(definst (ld iy (num w)) (emit #xfd #x2a (wl w) (wh w)))
(definst (ld (num w) hl) (emit #x22 (wl w) (wh w)))
(definst (ld (num w) bc) (emit #xed #x43 (wl w) (wh w)))
(definst (ld (num w) de) (emit #xed #x53 (wl w) (wh w)))
;; (definst (ld (num w) hl) (emit #xed #x6b (wl w) (wh w)))
(definst (ld (num w) ix) (emit #xdd #x22 (wl w) (wh w)))
(definst (ld (num w) iy) (emit #xdd #x22 (wl w) (wh w)))
(definst (ld (num w) sp) (emit #xed #x73 (wl w) (wh w)))
(definst (ld sp hl) (emit #xf9))
(definst (ld sp ix) (emit #xdd #xf9))
(definst (ld sp iy) (emit #xfd #xf9))

;; register exchange instructions
(definst (ex de hl) (emit #xeb))
(definst (ex (sp) hl) (emit #xe3))
(definst (ex (sp) ix) (emit #xdd #xe3))
(definst (ex (sp) iy) (emit #xfd #xe3))
(definst (ex af af) (emit #x08))
(definst (exx) (emit #xd9))

;; add num b instructions
(definst (add a a) (emit #x87))
(definst (add a b) (emit #x80))
(definst (add a c) (emit #x81))
(definst (add a d) (emit #x82))
(definst (add a e) (emit #x83))
(definst (add a h) (emit #x84))
(definst (add a l) (emit #x85))
(definst (add a (hl)) (emit #x86))
(definst (add a (ix num i)) (emit #xdd #x86 (bb i)))
(definst (add a (iy num i)) (emit #xfd #x86 (bb i)))
(definst (add a num b) (emit #xc6 (bb b)))

;; add num b carry-in instructions
(definst (adc a a) (emit #x8f))
(definst (adc a b) (emit #x88))
(definst (adc a c) (emit #x89))
(definst (adc a d) (emit #x8a))
(definst (adc a e) (emit #x8b))
(definst (adc a h) (emit #x8c))
(definst (adc a l) (emit #x8d))
(definst (adc a (hl)) (emit #x8e))
(definst (adc a (ix num i)) (emit #xdd #x8e (bb i)))
(definst (adc a (iy num i)) (emit #xfd #x8e (bb i)))
(definst (adc a num b) (emit #xce (bb b)))

;; substract num b instructions
(definst (sub a) (emit #x97))
(definst (sub b) (emit #x90))
(definst (sub c) (emit #x91))
(definst (sub d) (emit #x92))
(definst (sub e) (emit #x93))
(definst (sub h) (emit #x94))
(definst (sub l) (emit #x95))
(definst (sub (hl)) (emit #x96))
(definst (sub (ix num i)) (emit #xdd #x96 (bb i)))
(definst (sub (iy num i)) (emit #xfd #x96 (bb i)))
(definst (sub num b) (emit #xd6 (bb b)))

;; substract num b with borrow-in instructions
(definst (sbc a) (emit #x9f))
(definst (sbc b) (emit #x98))
(definst (sbc c) (emit #x99))
(definst (sbc d) (emit #x9a))
(definst (sbc e) (emit #x9b))
(definst (sbc h) (emit #x9c))
(definst (sbc l) (emit #x9d))
(definst (sbc (hl)) (emit #x9e))
(definst (sbc (ix num i)) (emit #xdd #x9e (bb i)))
(definst (sbc (iy num i)) (emit #xfd #x9e (bb i)))
(definst (sbc num b) (emit #xde (bb b)))

;; double num b add instructions
(definst (add hl bc) (emit #x09))
(definst (add hl de) (emit #x19))
(definst (add hl hl) (emit #x29))
(definst (add hl sp) (emit #x39))
(definst (add ix bc) (emit #xdd #x09))
(definst (add ix de) (emit #xdd #x19))
(definst (add ix ix) (emit #xdd #x29))
(definst (add ix sp) (emit #xdd #x39))
(definst (add iy bc) (emit #xfd #x09))
(definst (add iy de) (emit #xfd #x19))
(definst (add iy iy) (emit #xfd #x29))
(definst (add iy sp) (emit #xfd #x39))

;; double num b add with carry-in instructions
(definst (adc) (emit #xed #x4a))
(definst (adc hl de) (emit #xed #x5a))
(definst (adc hl hl) (emit #xed #x6a))
(definst (adc hl sp) (emit #xed #x7a))

;; double num b subtract with borrow-in instructions
(definst (sbc hl bc) (emit #xed #x42))
(definst (sbc hl de) (emit #xed #x52))
(definst (sbc hl hl) (emit #xed #x62))
(definst (sbc hl sp) (emit #xed #x72))

;; control instructions
(definst (di) (emit #xf3))
(definst (ei) (emit #xfb))
(definst (im 0) (emit #xed #x46))
(definst (im 1) (emit #xed #x56))
(definst (im 2) (emit #xed #x5e))
(definst (ld a i) (emit #xed #x57))
(definst (ld i a) (emit #xed #x47))
(definst (ld a r) (emit #xed #x5f))
(definst (ld r a) (emit #xed #x4f))
(definst (nop) (emit #x00))
(definst (halt) (emit #x76))

;; increment num b instructions
(definst (inc a) (emit #x3c))
(definst (inc b) (emit #x04))
(definst (inc c) (emit #x0c))
(definst (inc d) (emit #x14))
(definst (inc e) (emit #x1c))
(definst (inc h) (emit #x24))
(definst (inc l) (emit #x2c))
(definst (inc (hl)) (emit #x34))
(definst (inc (ix num i)) (emit #xdd #x34 (bb i)))
(definst (inc (iy num i)) (emit #xfd #x34 (bb i)))

;; decrement num b instructions
(definst (dec a) (emit #x3d))
(definst (dec b) (emit #x05))
(definst (dec c) (emit #x0d))
(definst (dec d) (emit #x15))
(definst (dec e) (emit #x1d))
(definst (dec h) (emit #x25))
(definst (dec l) (emit #x2d))
(definst (dec (hl)) (emit #x35))
(definst (dec (ix num i)) (emit #xdd #x35 (bb i)))
(definst (dec (iy num i)) (emit #xfd #x35 (bb i)))

;; increment register pair instructions
(definst (inc bc) (emit #x03))
(definst (inc de) (emit #x13))
(definst (inc hl) (emit #x23))
(definst (inc sp) (emit #x33))
(definst (inc ix) (emit #xdd #x23))
(definst (inc iy) (emit #xfd #x23))

;; decrement register pair instructions
(definst (dec bc) (emit #x0b))
(definst (dec de) (emit #x1b))
(definst (dec hl) (emit #x2b))
(definst (dec sp) (emit #x3b))
(definst (dec ix) (emit #xdd #x2b))
(definst (dec iy) (emit #xfd #x2b))

;; special accumulator and flag instructions
(definst (daa) (emit #x27))
(definst (cpl) (emit #x2f))
(definst (scf) (emit #x37))
(definst (ccf) (emit #x3f))
(definst (neg) (emit #xed #x44))

;; rotate instructions
(definst (rlca) (emit #x07))
(definst (rrca) (emit #x0f))
(definst (rla) (emit #x17))
(definst (rra) (emit #x1f))
(definst (rld) (emit #xed #x6f))
(definst (rrd) (emit #xed #x67))
(definst (rlc a) (emit #xcb #x07))
(definst (rlc b) (emit #xcb #x00))
(definst (rlc c) (emit #xcb #x01))
(definst (rlc d) (emit #xcb #x02))
(definst (rlc e) (emit #xcb #x03))
(definst (rlc h) (emit #xcb #x04))
(definst (rlc l) (emit #xcb #x05))
(definst (rlc (hl)) (emit #xcb #x06))
(definst (rlc (ix num i)) (emit #xdd #xcb (bb i) #x06))
(definst (rlc (iy num i)) (emit #xfd #xcb (bb i) #x06))
(definst (rl a) (emit #xcb #x17))
(definst (rl b) (emit #xcb #x10))
(definst (rl c) (emit #xcb #x11))
(definst (rl d) (emit #xcb #x12))
(definst (rl e) (emit #xcb #x13))
(definst (rl h) (emit #xcb #x14))
(definst (rl l) (emit #xcb #x15))
(definst (rl (hl)) (emit #xcb #x16))
(definst (rl (ix num i)) (emit #xdd #xcb (bb i) #x16))
(definst (rl (iy num i)) (emit #xfd #xcb (bb i) #x16))
(definst (rrc a) (emit #xcb #x0f))
(definst (rrc b) (emit #xcb #x08))
(definst (rrc c) (emit #xcb #x09))
(definst (rrc d) (emit #xcb #x0a))
(definst (rrc e) (emit #xcb #x0b))
(definst (rrc h) (emit #xcb #x0c))
(definst (rrc l) (emit #xcb #x0d))
(definst (rrc (hl)) (emit #xcb #x0e))
(definst (rrc (ix num i)) (emit #xdd #xcb (bb i) #x0e))
(definst (rrc (iy num i)) (emit #xfd #xcb (bb i) #x0e))
(definst (rl a) (emit #xcb #x1f))
(definst (rl b) (emit #xcb #x18))
(definst (rl c) (emit #xcb #x19))
(definst (rl d) (emit #xcb #x1a))
(definst (rl e) (emit #xcb #x1b))
(definst (rl h) (emit #xcb #x1c))
(definst (rl l) (emit #xcb #x1d))
(definst (rl (hl)) (emit #xcb #x1e))
(definst (rl (ix num i)) (emit #xdd #xcb (bb i) #x1e))
(definst (rl (iy num i)) (emit #xfd #xcb (bb i) #x1e))

;; logical num b instructions
(definst (and a) (emit #xa7))
(definst (and b) (emit #xa0))
(definst (and c) (emit #xa1))
(definst (and d) (emit #xa2))
(definst (and e) (emit #xa3))
(definst (and h) (emit #xa4))
(definst (and l) (emit #xa5))
(definst (and (hl)) (emit #xa6))
(definst (and (ix num i)) (emit #xdd #xa6 (bb i)))
(definst (and (iy num i)) (emit #xfd #xa6 (bb i)))
(definst (and num b) (emit #xe6 (bb b)))
(definst (xor a) (emit #xaf))
(definst (xor b) (emit #xa8))
(definst (xor c) (emit #xa9))
(definst (xor d) (emit #xaa))
(definst (xor e) (emit #xab))
(definst (xor h) (emit #xac))
(definst (xor l) (emit #xad))
(definst (xor (hl)) (emit #xae))
(definst (xor (ix num i)) (emit #xdd #xae (bb i)))
(definst (xor (iy num i)) (emit #xfd #xae (bb i)))
(definst (xor num b) (emit #xee (bb b)))
(definst (or a) (emit #xb7))
(definst (or b) (emit #xb0))
(definst (or c) (emit #xb1))
(definst (or d) (emit #xb2))
(definst (or e) (emit #xb3))
(definst (or h) (emit #xb4))
(definst (or l) (emit #xb5))
(definst (or (hl)) (emit #xb6))
(definst (or (ix num i)) (emit #xdd #xb6 (bb i)))
(definst (or (iy num i)) (emit #xfd #xb6 (bb i)))
(definst (or num b) (emit #xf6 (bb b)))
(definst (cp a) (emit #xbf))
(definst (cp b) (emit #xb8))
(definst (cp c) (emit #xb9))
(definst (cp d) (emit #xba))
(definst (cp e) (emit #xbb))
(definst (cp h) (emit #xbc))
(definst (cp l) (emit #xbd))
(definst (cp (hl)) (emit #xbe))
(definst (cp (ix num i)) (emit #xdd #xbe (bb i)))
(definst (cp (iy num i)) (emit #xfd #xbe (bb i)))
(definst (cp num b) (emit #xfe (bb b)))
(definst (cpi) (emit #xed #xa1))
(definst (cpir) (emit #xed #xb1))
(definst (cpd) (emit #xed #xa9))
(definst (cpdr) (emit #xed #xb9))

;; branch control/program counter load instructions
(definst (jp num w) (emit #xc3 (wl w) (wh w)))
(definst (jp nz num w) (emit #xc2 (wl w) (wh w)))
(definst (jp z num w) (emit #xca (wl w) (wh w)))
(definst (jp nc num w) (emit #xd2 (wl w) (wh w)))
(definst (jp c num w) (emit #xda (wl w) (wh w)))
(definst (jp po num w) (emit #xe2 (wl w) (wh w)))
(definst (jp pe num w) (emit #xea (wl w) (wh w)))
(definst (jp p num w) (emit #xf2 (wl w) (wh w)))
(definst (jp m num w) (emit #xfa (wl w) (wh w)))
(definst (jp (hl)) (emit #xe9))
(definst (jp (ix)) (emit #xdd #xe9))
(definst (jp (iy)) (emit #xfd #xe9))
(definst (jr num r) (emit #x18 (ri r)))
(definst (jr nz num r) (emit #x20 (ri r)))
(definst (jr z num r) (emit #x28 (ri r)))
(definst (jr nc num r) (emit #x30 (ri r)))
(definst (jr c num r) (emit #x38 (ri r)))
(definst (djnz num r) (emit #x10 (ri r)))
(definst (call num w) (emit #xcd (wl w) (wh w)))
(definst (call nz num w) (emit #xc4 (wl w) (wh w)))
(definst (call z num w) (emit #xcc (wl w) (wh w)))
(definst (call nc num w) (emit #xd4 (wl w) (wh w)))
(definst (call c num w) (emit #xdc (wl w) (wh w)))
(definst (call po num w) (emit #xe4 (wl w) (wh w)))
(definst (call pe num w) (emit #xec (wl w) (wh w)))
(definst (call p num w) (emit #xf4 (wl w) (wh w)))
(definst (call m num w) (emit #xfc (wl w) (wh w)))
(definst (ret) (emit #xc9))
(definst (ret nz) (emit #xc0))
(definst (ret z) (emit #xc8))
(definst (ret nc) (emit #xd0))
(definst (ret c) (emit #xd8))
(definst (ret po) (emit #xe0))
(definst (ret pe) (emit #xe8))
(definst (ret p) (emit #xf0))
(definst (ret m) (emit #xf8))
(definst (reti) (emit #xed #x4d))
(definst (retn) (emit #xed #x45))
(definst (rst #x0) (emit #xc7))
(definst (rst #x8) (emit #xcf))
(definst (rst #x10) (emit #xd7))
(definst (rst #x18) (emit #xdf))
(definst (rst #x20) (emit #xe7))
(definst (rst #x28) (emit #xef))
(definst (rst #x30) (emit #xf7))
(definst (rst #x38) (emit #xff))

;; stack operation instructions
(definst (push bc) (emit #xc5))
(definst (push de) (emit #xd5))
(definst (push hl) (emit #xe5))
(definst (push af) (emit #xf5))
(definst (push ix) (emit #xdd #xe5))
(definst (push iy) (emit #xfd #xe5))
(definst (pop bc) (emit #xc1))
(definst (pop de) (emit #xd1))
(definst (pop hl) (emit #xe1))
(definst (pop af) (emit #xf1))
(definst (pop ix) (emit #xdd #xe1))
(definst (pop iy) (emit #xfd #xe1))

;; input/output instructions
(definst (in a (num b)) (emit #xdb (bb b)))
(definst (in a (c)) (emit #xed #x78))
(definst (in b (c)) (emit #xed #x40))
(definst (in c (c)) (emit #xed #x48))
(definst (in d (c)) (emit #xed #x50))
(definst (in) (emit #xed #x58))
(definst (in h (c)) (emit #xed #x60))
(definst (in l (c)) (emit #xed #x68))
(definst (ini) (emit #xed #xa2))
(definst (inir) (emit #xed #xb2))
(definst (ind) (emit #xed #xaa))
(definst (indr) (emit #xed #xba))
(definst (out (num b) a) (emit #xd3 (bb b)))
(definst (out (c) a) (emit #xed #x79))
(definst (out (c) b) (emit #xed #x41))
(definst (out (c) c) (emit #xed #x49))
(definst (out (c) d) (emit #xed #x51))
(definst (out (c) e) (emit #xed #x59))
(definst (out (c) h) (emit #xed #x61))
(definst (out (c) l) (emit #xed #x69))
(definst (outi) (emit #xed #xa3))
(definst (otir) (emit #xed #xb3))
(definst (outd) (emit #xed #xab))
(definst (otdr) (emit #xed #xbb))

;; data transfer instructions
(definst (ldi) (emit #xed #xa0))
(definst (ldir) (emit #xed #xb0))
(definst (ldd) (emit #xed #xa8))
(definst (lddr) (emit #xed #xb8))

;; bit manipulation instructions
(definst (bit 0 a) (emit #xcb #x47))
(definst (bit 0 b) (emit #xcb #x40))
(definst (bit 0 c) (emit #xcb #x41))
(definst (bit 0 d) (emit #xcb #x42))
(definst (bit 0 e) (emit #xcb #x43))
(definst (bit 0 h) (emit #xcb #x44))
(definst (bit 0 l) (emit #xcb #x45))
(definst (bit 0 (hl)) (emit #xcb #x46))
(definst (bit 0 (ix num i)) (emit #xdd #xcb (bb i) #x46))
(definst (bit 0 (iy num i)) (emit #xfd #xcb (bb i) #x46))
(definst (bit 1 a) (emit #xcb #x4f))
(definst (bit 1 b) (emit #xcb #x48))
(definst (bit 1 c) (emit #xcb #x49))
(definst (bit 1 d) (emit #xcb #x4a))
(definst (bit 1 e) (emit #xcb #x4b))
(definst (bit 1 h) (emit #xcb #x4c))
(definst (bit 1 l) (emit #xcb #x4d))
(definst (bit 1 (hl)) (emit #xcb #x4e))
(definst (bit 1 (ix num i)) (emit #xdd #xcb (bb i) #x4e))
(definst (bit 1 (iy num i)) (emit #xfd #xcb (bb i) #x4e))
(definst (bit 2 a) (emit #xcb #x57))
(definst (bit 2 b) (emit #xcb #x50))
(definst (bit 2 c) (emit #xcb #x51))
(definst (bit 2 d) (emit #xcb #x52))
(definst (bit 2 e) (emit #xcb #x53))
(definst (bit 2 h) (emit #xcb #x54))
(definst (bit 2 l) (emit #xcb #x55))
(definst (bit 2 (hl)) (emit #xcb #x56))
(definst (bit 2 (ix num i)) (emit #xdd #xcb (bb i) #x56))
(definst (bit 2 (iy num i)) (emit #xfd #xcb (bb i) #x56))
(definst (bit 3 a) (emit #xcb #x5f))
(definst (bit 3 b) (emit #xcb #x58))
(definst (bit 3 c) (emit #xcb #x59))
(definst (bit 3 d) (emit #xcb #x5a))
(definst (bit 3 e) (emit #xcb #x5b))
(definst (bit 3 h) (emit #xcb #x5c))
(definst (bit 3 l) (emit #xcb #x5d))
(definst (bit 3 (hl)) (emit #xcb #x5e))
(definst (bit 3 (ix num i)) (emit #xdd #xcb (bb i) #x5e))
(definst (bit 3 (iy num i)) (emit #xfd #xcb (bb i) #x5e))
(definst (bit 4 a) (emit #xcb #x67))
(definst (bit 4 b) (emit #xcb #x60))
(definst (bit 4 c) (emit #xcb #x61))
(definst (bit 4 d) (emit #xcb #x62))
(definst (bit 4 e) (emit #xcb #x63))
(definst (bit 4 h) (emit #xcb #x64))
(definst (bit 4 l) (emit #xcb #x65))
(definst (bit 4 (hl)) (emit #xcb #x66))
(definst (bit 4 (ix num i)) (emit #xdd #xcb (bb i) #x66))
(definst (bit 4 (iy num i)) (emit #xfd #xcb (bb i) #x66))
(definst (bit 5 a) (emit #xcb #x6f))
(definst (bit 5 b) (emit #xcb #x68))
(definst (bit 5 c) (emit #xcb #x69))
(definst (bit 5 d) (emit #xcb #x6a))
(definst (bit 5 e) (emit #xcb #x6b))
(definst (bit 5 h) (emit #xcb #x6c))
(definst (bit 5 l) (emit #xcb #x6d))
(definst (bit 5 (hl)) (emit #xcb #x6e))
(definst (bit 5 (ix num i)) (emit #xdd #xcb (bb i) #x6e))
(definst (bit 5 (iy num i)) (emit #xfd #xcb (bb i) #x6e))
(definst (bit 6 a) (emit #xcb #x77))
(definst (bit 6 b) (emit #xcb #x70))
(definst (bit 6 c) (emit #xcb #x71))
(definst (bit 6 d) (emit #xcb #x72))
(definst (bit 6 e) (emit #xcb #x73))
(definst (bit 6 h) (emit #xcb #x74))
(definst (bit 6 l) (emit #xcb #x75))
(definst (bit 6 (hl)) (emit #xcb #x76))
(definst (bit 6 (ix num i)) (emit #xdd #xcb (bb i) #x76))
(definst (bit 6 (iy num i)) (emit #xfd #xcb (bb i) #x76))
(definst (bit 7 a) (emit #xcb #x7f))
(definst (bit 7 b) (emit #xcb #x78))
(definst (bit 7 c) (emit #xcb #x79))
(definst (bit 7 d) (emit #xcb #x7a))
(definst (bit 7 e) (emit #xcb #x7b))
(definst (bit 7 h) (emit #xcb #x7c))
(definst (bit 7 l) (emit #xcb #x7d))
(definst (bit 7 (hl)) (emit #xcb #x7e))
(definst (bit 7 (ix num i)) (emit #xdd #xcb (bb i) #x7e))
(definst (bit 7 (iy num i)) (emit #xfd #xcb (bb i) #x7e))
(definst (res 0 a) (emit #xcb #x87))
(definst (res 0 b) (emit #xcb #x80))
(definst (res 0 c) (emit #xcb #x81))
(definst (res 0 d) (emit #xcb #x82))
(definst (res 0 e) (emit #xcb #x83))
(definst (res 0 h) (emit #xcb #x84))
(definst (res 0 l) (emit #xcb #x85))
(definst (res 0 (hl)) (emit #xcb #x86))
(definst (res 0 (ix num i)) (emit #xdd #xcb (bb i) #x86))
(definst (res 0 (iy num i)) (emit #xfd #xcb (bb i) #x86))
(definst (res 1 a) (emit #xcb #x8f))
(definst (res 1 b) (emit #xcb #x88))
(definst (res 1 c) (emit #xcb #x89))
(definst (res 1 d) (emit #xcb #x8a))
(definst (res 1 e) (emit #xcb #x8b))
(definst (res 1 h) (emit #xcb #x8c))
(definst (res 1 l) (emit #xcb #x8d))
(definst (res 1 (hl)) (emit #xcb #x8e))
(definst (res 1 (ix num i)) (emit #xdd #xcb (bb i) #x8e))
(definst (res 1 (iy num i)) (emit #xfd #xcb (bb i) #x8e))
(definst (res 2 a) (emit #xcb #x97))
(definst (res 2 b) (emit #xcb #x90))
(definst (res 2 c) (emit #xcb #x91))
(definst (res 2 d) (emit #xcb #x92))
(definst (res 2 e) (emit #xcb #x93))
(definst (res 2 h) (emit #xcb #x94))
(definst (res 2 l) (emit #xcb #x95))
(definst (res 2 (hl)) (emit #xcb #x96))
(definst (res 2 (ix num i)) (emit #xdd #xcb (bb i) #x96))
(definst (res 2 (iy num i)) (emit #xfd #xcb (bb i) #x96))
(definst (res 3 a) (emit #xcb #x9f))
(definst (res 3 b) (emit #xcb #x98))
(definst (res 3 c) (emit #xcb #x99))
(definst (res 3 d) (emit #xcb #x9a))
(definst (res 3 e) (emit #xcb #x9b))
(definst (res 3 h) (emit #xcb #x9c))
(definst (res 3 l) (emit #xcb #x9d))
(definst (res 3 (hl)) (emit #xcb #x9e))
(definst (res 3 (ix num i)) (emit #xdd #xcb (bb i) #x9e))
(definst (res 3 (iy num i)) (emit #xfd #xcb (bb i) #x9e))
(definst (res 4 a) (emit #xcb #xa7))
(definst (res 4 b) (emit #xcb #xa0))
(definst (res 4 c) (emit #xcb #xa1))
(definst (res 4 d) (emit #xcb #xa2))
(definst (res 4 e) (emit #xcb #xa3))
(definst (res 4 h) (emit #xcb #xa4))
(definst (res 4 l) (emit #xcb #xa5))
(definst (res 4 (hl)) (emit #xcb #xa6))
(definst (res 4 (ix num i)) (emit #xdd #xcb (bb i) #xa6))
(definst (res 4 (iy num i)) (emit #xfd #xcb (bb i) #xa6))
(definst (res 5 a) (emit #xcb #xaf))
(definst (res 5 b) (emit #xcb #xa8))
(definst (res 5 c) (emit #xcb #xa9))
(definst (res 5 d) (emit #xcb #xaa))
(definst (res 5 e) (emit #xcb #xab))
(definst (res 5 h) (emit #xcb #xac))
(definst (res 5 l) (emit #xcb #xad))
(definst (res 5 (hl)) (emit #xcb #xae))
(definst (res 5 (ix num i)) (emit #xdd #xcb (bb i) #xae))
(definst (res 5 (iy num i)) (emit #xfd #xcb (bb i) #xae))
(definst (res 6 a) (emit #xcb #xb7))
(definst (res 6 b) (emit #xcb #xb0))
(definst (res 6 c) (emit #xcb #xb1))
(definst (res 6 d) (emit #xcb #xb2))
(definst (res 6 e) (emit #xcb #xb3))
(definst (res 6 h) (emit #xcb #xb4))
(definst (res 6 l) (emit #xcb #xb5))
(definst (res 6 (hl)) (emit #xcb #xb6))
(definst (res 6 (ix num i)) (emit #xdd #xcb (bb i) #xb6))
(definst (res 6 (iy num i)) (emit #xfd #xcb (bb i) #xb6))
(definst (res 7 a) (emit #xcb #xbf))
(definst (res 7 b) (emit #xcb #xb8))
(definst (res 7 c) (emit #xcb #xb9))
(definst (res 7 d) (emit #xcb #xba))
(definst (res 7 e) (emit #xcb #xbb))
(definst (res 7 h) (emit #xcb #xbc))
(definst (res 7 l) (emit #xcb #xbd))
(definst (res 7 (hl)) (emit #xcb #xbe))
(definst (res 7 (ix num i)) (emit #xdd #xcb (bb i) #xbe))
(definst (res 7 (iy num i)) (emit #xfd #xcb (bb i) #xbe))
(definst (set 0 a) (emit #xcb #xc7))
(definst (set 0 b) (emit #xcb #xc0))
(definst (set 0 c) (emit #xcb #xc1))
(definst (set 0 d) (emit #xcb #xc2))
(definst (set 0 e) (emit #xcb #xc3))
(definst (set 0 h) (emit #xcb #xc4))
(definst (set 0 l) (emit #xcb #xc5))
(definst (set 0 (hl)) (emit #xcb #xc6))
(definst (set 0 (ix num i)) (emit #xdd #xcb (bb i) #xc6))
(definst (set 0 (iy num i)) (emit #xfd #xcb (bb i) #xc6))
(definst (set 1 a) (emit #xcb #xcf))
(definst (set 1 b) (emit #xcb #xc8))
(definst (set 1 c) (emit #xcb #xc9))
(definst (set 1 d) (emit #xcb #xca))
(definst (set 1 e) (emit #xcb #xcb))
(definst (set 1 h) (emit #xcb #xcc))
(definst (set 1 l) (emit #xcb #xcd))
(definst (set 1 (hl)) (emit #xcb #xce))
(definst (set 1 (ix num i)) (emit #xdd #xcb (bb i) #xce))
(definst (set 1 (iy num i)) (emit #xfd #xcb (bb i) #xce))
(definst (set 2 a) (emit #xcb #xd7))
(definst (set 2 b) (emit #xcb #xd0))
(definst (set 2 c) (emit #xcb #xd1))
(definst (set 2 d) (emit #xcb #xd2))
(definst (set 2 e) (emit #xcb #xd3))
(definst (set 2 h) (emit #xcb #xd4))
(definst (set 2 l) (emit #xcb #xd5))
(definst (set 2 (hl)) (emit #xcb #xd6))
(definst (set 2 (ix num i)) (emit #xdd #xcb (bb i) #xd6))
(definst (set 2 (iy num i)) (emit #xfd #xcb (bb i) #xd6))
(definst (set 3 a) (emit #xcb #xdf))
(definst (set 3 b) (emit #xcb #xd8))
(definst (set 3 c) (emit #xcb #xd9))
(definst (set 3 d) (emit #xcb #xda))
(definst (set 3 e) (emit #xcb #xdb))
(definst (set 3 h) (emit #xcb #xdc))
(definst (set 3 l) (emit #xcb #xdd))
(definst (set 3 (hl)) (emit #xcb #xde))
(definst (set 3 (ix num i)) (emit #xdd #xcb (bb i) #xde))
(definst (set 3 (iy num i)) (emit #xfd #xcb (bb i) #xde))
(definst (set 4 a) (emit #xcb #xe7))
(definst (set 4 b) (emit #xcb #xe0))
(definst (set 4 c) (emit #xcb #xe1))
(definst (set 4 d) (emit #xcb #xe2))
(definst (set 4 e) (emit #xcb #xe3))
(definst (set 4 h) (emit #xcb #xe4))
(definst (set 4 l) (emit #xcb #xe5))
(definst (set 4 (hl)) (emit #xcb #xe6))
(definst (set 4 (ix num i)) (emit #xdd #xcb (bb i) #xe6))
(definst (set 4 (iy num i)) (emit #xfd #xcb (bb i) #xe6))
(definst (set 5 a) (emit #xcb #xef))
(definst (set 5 b) (emit #xcb #xe8))
(definst (set 5 c) (emit #xcb #xe9))
(definst (set 5 d) (emit #xcb #xea))
(definst (set 5 e) (emit #xcb #xeb))
(definst (set 5 h) (emit #xcb #xec))
(definst (set 5 l) (emit #xcb #xed))
(definst (set 5 (hl)) (emit #xcb #xee))
(definst (set 5 (ix num i)) (emit #xdd #xcb (bb i) #xee))
(definst (set 5 (iy num i)) (emit #xfd #xcb (bb i) #xee))
(definst (set 6 a) (emit #xcb #xf7))
(definst (set 6 b) (emit #xcb #xf0))
(definst (set 6 c) (emit #xcb #xf1))
(definst (set 6 d) (emit #xcb #xf2))
(definst (set 6 e) (emit #xcb #xf3))
(definst (set 6 h) (emit #xcb #xf4))
(definst (set 6 l) (emit #xcb #xf5))
(definst (set 6 (hl)) (emit #xcb #xf6))
(definst (set 6 (ix num i)) (emit #xdd #xcb (bb i) #xf6))
(definst (set 6 (iy num i)) (emit #xfd #xcb (bb i) #xf6))
(definst (set 7 a) (emit #xcb #xff))
(definst (set 7 b) (emit #xcb #xf8))
(definst (set 7 c) (emit #xcb #xf9))
(definst (set 7 d) (emit #xcb #xfa))
(definst (set 7 e) (emit #xcb #xfb))
(definst (set 7 h) (emit #xcb #xfc))
(definst (set 7 l) (emit #xcb #xfd))
(definst (set 7 (hl)) (emit #xcb #xfe))
(definst (set 7 (ix num i)) (emit #xdd #xcb (bb i) #xfe))
(definst (set 7 (iy num i)) (emit #xfd #xcb (bb i) #xfe))

;; bit shift instructions
(definst (sla a) (emit #xcb #x27))
(definst (sla b) (emit #xcb #x20))
(definst (sla c) (emit #xcb #x21))
(definst (sla d) (emit #xcb #x22))
(definst (sla e) (emit #xcb #x23))
(definst (sla h) (emit #xcb #x24))
(definst (sla l) (emit #xcb #x25))
(definst (sla (hl)) (emit #xcb #x26))
(definst (sla (ix num i)) (emit #xdd #xcb (bb i) #x26))
(definst (sla (iy num i)) (emit #xfd #xcb (bb i) #x26))
(definst (sra a) (emit #xcb #x2f))
(definst (sra b) (emit #xcb #x28))
(definst (sra c) (emit #xcb #x29))
(definst (sra d) (emit #xcb #x2a))
(definst (sra e) (emit #xcb #x2b))
(definst (sra h) (emit #xcb #x2c))
(definst (sra l) (emit #xcb #x2d))
(definst (sra (hl)) (emit #xcb2e))
(definst (sra (ix num i)) (emit #xdd #xcb (bb i) #x2e))
(definst (sra (iy num i)) (emit #xfd #xcb (bb i) #x2e))
(definst (srl a) (emit #xcb #x3f))
(definst (srl b) (emit #xcb #x38))
(definst (srl c) (emit #xcb #x39))
(definst (srl d) (emit #xcb #x3a))
(definst (srl e) (emit #xcb #x3b))
(definst (srl h) (emit #xcb #x3c))
(definst (srl l) (emit #xcb #x3d))
(definst (srl (hl)) (emit #xcb #x3e))
(definst (srl (ix num i)) (emit #xdd #xcb (bb i) #x3e))
(definst (srl (iy num i)) (emit #xfd #xcb (bb i) #x3e))

;; undocumented inst
(definst (inc ixh) (emit #xdd #x24))
(definst (inc iyh) (emit #xfd #x24))
(definst (dec ixh) (emit #xdd #x25))
(definst (dec iyh) (emit #xfd #x25))
(definst (ld ixh num b) (emit #xdd #x26 (bb b)))
(definst (ld iyh num b) (emit #xfd #x26 (bb b)))
(definst (inc ixl) (emit #xdd #x2c))
(definst (inc iyl) (emit #xfd #x2c))
(definst (dec ixl) (emit #xdd #x2d))
(definst (dec iyl) (emit #xfd #x2d))
(definst (ld ixl num b) (emit #xdd #x2e (bb b)))
(definst (ld iyl num b) (emit #xfd #x2e (bb b)))
(definst (ld b ixh) (emit #xdd #x44))
(definst (ld b iyh) (emit #xfd #x44))
(definst (ld b ixl) (emit #xdd #x45))
(definst (ld b iyl) (emit #xfd #x45))
(definst (ld c ixh) (emit #xdd #x4c))
(definst (ld c iyh) (emit #xfd #x4c))
(definst (ld c ixl) (emit #xdd #x4d))
(definst (ld c iyl) (emit #xfd #x4d))
(definst (ld d ixh) (emit #xdd #x54))
(definst (ld d iyh) (emit #xfd #x54))
(definst (ld d ixl) (emit #xdd #x55))
(definst (ld d iyl) (emit #xfd #x55))
(definst (ld e ixh) (emit #xdd #x5c))
(definst (ld e iyh) (emit #xfd #x5c))
(definst (ld e ixl) (emit #xdd #x5d))
(definst (ld e iyl) (emit #xfd #x5d))
(definst (ld ixh b) (emit #xdd #x60))
(definst (ld iyh b) (emit #xfd #x60))
(definst (ld ixh c) (emit #xdd #x61))
(definst (ld iyh c) (emit #xfd #x61))
(definst (ld ixh d) (emit #xdd #x62))
(definst (ld iyh d) (emit #xfd #x62))
(definst (ld ixh e) (emit #xdd #x63))
(definst (ld iyh e) (emit #xfd #x63))
(definst (ld ixh ixh ) (emit #xdd #x64))
(definst (ld iyh iyh) (emit #xfd #x64))
(definst (ld ixh ixl ) (emit #xdd #x65))
(definst (ld iyh iyl) (emit #xfd #x65))
(definst (ld ixh a) (emit #xdd #x67))
(definst (ld iyh a) (emit #xfd #x67))
(definst (ld ixl b) (emit #xdd #x68))
(definst (ld iyl b) (emit #xfd #x68))
(definst (ld ixl c) (emit #xdd #x69))
(definst (ld iyl c) (emit #xfd #x69))
(definst (ld ixl d) (emit #xdd #x6a))
(definst (ld iyl d) (emit #xfd #x6a))
(definst (ld ixl e) (emit #xdd #x6b))
(definst (ld iyl e) (emit #xfd #x6b))
(definst (ld ixl ixh ) (emit #xdd #x6c))
(definst (ld iyl iyh) (emit #xfd #x6c))
(definst (ld ixl ixl ) (emit #xdd #x6d))
(definst (ld iyl iyl) (emit #xfd #x6d))
(definst (ld ixl a) (emit #xdd #x6f))
(definst (ld iyl a) (emit #xfd #x6f))
(definst (ld a ixh) (emit #xdd #x7c))
(definst (ld a iyh) (emit #xfd #x7c))
(definst (ld a ixl) (emit #xdd #x7d))
(definst (ld a iyl) (emit #xfd #x7d))
(definst (add a ixh) (emit #xdd #x84))
(definst (add a iyh) (emit #xfd #x84))
(definst (add a ixl) (emit #xdd #x85))
(definst (add a iyl) (emit #xfd #x85))
(definst (adc a ixh) (emit #xdd #x8c))
(definst (adc a iyh) (emit #xfd #x8c))
(definst (adc a ixl) (emit #xdd #x8d))
(definst (adc a iyl) (emit #xfd #x8d))
(definst (sub ixh) (emit #xdd #x94))
(definst (sub iyh) (emit #xfd #x94))
(definst (sub ixl) (emit #xdd #x95))
(definst (sub iyl) (emit #xfd #x95))
(definst (sbc a ixh) (emit #xdd #x9c))
(definst (sbc a iyh) (emit #xfd #x9c))
(definst (sbc a ixl) (emit #xdd #x9d))
(definst (sbc a iyl) (emit #xfd #x9d))
(definst (and ixh) (emit #xdd #xa4))
(definst (and iyh) (emit #xfd #xa4))
(definst (and ixl) (emit #xdd #xa5))
(definst (and iyl) (emit #xfd #xa5))
(definst (xor ixh) (emit #xdd #xac))
(definst (xor iyh) (emit #xfd #xac))
(definst (xor ixl) (emit #xdd #xad))
(definst (xor iyl) (emit #xfd #xad))
(definst (or ixh) (emit #xdd #xb4))
(definst (or iyh) (emit #xfd #xb4))
(definst (or ixl) (emit #xdd #xb5))
(definst (or iyl) (emit #xfd #xb5))
(definst (cp ixh) (emit #xdd #xbc))
(definst (cp iyh) (emit #xfd #xbc))
(definst (cp ixl) (emit #xdd #xbd))
(definst (cp iyl) (emit #xfd #xbd))
