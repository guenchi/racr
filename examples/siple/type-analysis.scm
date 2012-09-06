; This program and the accompanying materials are made available under the
; terms of the MIT license (X11 license) which accompanies this distribution.

; Author: C. Bürger

#!r6rs

(library
 (siple type-analysis)
 (export
  specify-type-analysis)
 (import (rnrs) (racr) (siple type))
 
 (define specify-type-analysis
   (lambda (siple-specification)
     (with-specification
      siple-specification
      
      (ag-rule
       type
       ;;; Statements with Type Constraints:
       (VariableDeclaration
        (lambda (n)
          (ast-child 'declaredtype n)))
       
       (ProcedureDeclaration
        (lambda (n)
          (type-procedure
           (ast-child 'returntype n)
           (let ((paras (list)))
             (ast-for-each-child
              (lambda (i n)
                (set! paras (append paras (list (att-value 'type n)))))
              (ast-child 'Parameters n))
             paras))))
       
       (VariableAssignment
        (lambda (n)
          (let ((l-type (att-value 'type (ast-child 'LHand n))))
            (if (type-pointer? l-type)
                (type-eq? (type-rtype l-type) (att-value 'type (ast-child 'RHand n)))
                (type-error-type)))))
       
       (ProcedureReturn
        (lambda (n)
          (let ((procedure-decl (att-value 'procedure-in-context n)))
            (if procedure-decl
                (let ((procedure-rtype (type-rtype (att-value 'type procedure-decl))))
                  (if (> (ast-num-children (ast-child 'Expression* n)) 0)
                      (type-eq? (att-value 'type (ast-child 1 (ast-child 'Expression* n))) procedure-rtype)
                      (if (type-undefined? procedure-rtype)
                          procedure-rtype
                          (type-error-type))))
                (type-error-type)))))
       
       (Write
        (lambda (n)
          (let ((r-type (att-value 'type (ast-child 'Expression n))))
            (if (or (type-pointer? r-type) (type-procedure? r-type) (type-undefined? r-type))
                (type-error-type)
                r-type))))
       
       (Read
        (lambda (n)
          (let* ((type (att-value 'type (ast-child 'Expression n)))
                 (rtype (type-rtype type)))
            (if (type-pointer? type)
                (if (or (type-pointer? rtype) (type-procedure? rtype) (type-undefined? rtype))
                    (type-error-type)
                    type)
                (type-error-type)))))
       
       ;;; Expressions' Type:
       
       (Constant
        (lambda (n)
          (cond
            ((not (eq? (att-value 'as-boolean n) 'siple:nil)) (type-boolean))
            ((not (eq? (att-value 'as-integer n) 'siple:nil)) (type-integer))
            (else (type-real)))))
       
       (Reference
        (lambda (n)
          (let ((decl (att-value 'declaration n)))
            (if decl
                (type-pointer (att-value 'type decl))
                (type-error-type)))))
       
       (ProcedureCall
        (lambda (n)
          (let* ((argument-list (ast-child 'Arguments n))
                 (procedure-type (att-value 'type (ast-child 'Procedure n)))
                 (result (type-rtype procedure-type)))
            (if (type-procedure? procedure-type)
                (if (= (length (type-paras procedure-type)) (ast-num-children argument-list))
                    (ast-for-each-child
                     (lambda (i n)
                       (if (not (type-beq? (att-value 'type n) (list-ref (type-paras procedure-type) (- i 1))))
                           (set! result (type-error-type))))
                     argument-list)
                    (set! result (type-error-type)))
                (set! result (type-error-type)))
            result)))
       
       (Not
        (lambda (n)
          (if (type-boolean? (att-value 'type (ast-child 'Operand n)))
              (type-boolean)
              (type-error-type))))
       
       (UMinus
        (lambda (n)
          (let ((op-type (att-value 'type (ast-child 'Operand n))))
            (if (type-number? op-type)
                op-type
                (type-error-type)))))
       
       (RealCoercion
        (lambda (n)
          (if (type-integer? (att-value 'type (ast-child 'Operand n)))
              (type-real)
              (type-error-type))))
       
       (Dereference
        (lambda (n)
          (let ((op-type (att-value 'type (ast-child 'Operand n))))
            (if (type-pointer? op-type)
                (type-rtype op-type)
                (type-error-type)))))
       
       (LogicExpression
        (lambda (n)
          (if (and (type-boolean? (att-value 'type (ast-child 'Operand1 n))) (type-boolean? (att-value 'type (ast-child 'Operand2 n))))
              (type-boolean)
              (type-error-type))))
       
       (EqualityExpression
        (lambda (n)
          (let ((op1-type (att-value 'type (ast-child 'Operand1 n)))
                (op2-type (att-value 'type (ast-child 'Operand2 n))))
            (if (and (type-number? op1-type) (type-beq? op1-type op2-type))
                (type-boolean)
                (type-error-type)))))
       
       (Equal
        (lambda (n)
          (if (type-beq? (att-value 'type (ast-child 'Operand1 n)) (att-value 'type (ast-child 'Operand2 n)))
              (type-boolean)
              (type-error-type))))
       
       (ArithmeticExpression
        (lambda (n)
          (let ((op1-type (att-value 'type (ast-child 'Operand1 n)))
                (op2-type (att-value 'type (ast-child 'Operand2 n))))
            (if (and (type-number? op1-type) (type-beq? op1-type op2-type))
                op1-type
                (type-error-type))))))))))