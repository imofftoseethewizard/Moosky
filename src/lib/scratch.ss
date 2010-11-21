(CALL
 (PAREN
  (FUNCTION #f ()
            ((STATEMENT
              (RETURN
               (ASSIGN (MEMBER-EXP (IDENTIFIER "$")
                                   (LITERAL "map"))
                       (PAREN (FUNCTION #f ((IDENTIFIER "P") (IDENTIFIER "L"))
                                        ((STATEMENT
                                          (VAR ((IDENTIFIER $P_1361)
                                                (IDENTIFIER $L_1362)
                                                (IDENTIFIER $R_1359)
                                                ((IDENTIFIER $C_1360) (CALL (IDENTIFIER Object) ())))))
                                         (STATEMENT
                                          (WHILE
                                           (STRICTLY-EQUAL
                                            (PAREN
                                             (ASSIGN (IDENTIFIER $R_1359)
                                                     (CONDITIONAL
                                                      (CALL (MEMBER-EXP (IDENTIFIER "$") (LITERAL "null?"))
                                                            ((IDENTIFIER "L")))
                                                      (IDENTIFIER "$nil")
                                                      (CALL (IDENTIFIER cons)
                                                            ((CALL (IDENTIFIER "P")
                                                                   ((CALL (IDENTIFIER car) ((IDENTIFIER "L")))))
                                                             (SEQUENCE (ASSIGN (IDENTIFIER $P_1361) (IDENTIFIER "P"))
                                                                       (ASSIGN (IDENTIFIER $L_1362) (CALL (IDENTIFIER cdr)
                                                                                                          ((IDENTIFIER "L"))))
                                                                       (ASSIGN (IDENTIFIER P) (IDENTIFIER $P_1361))
                                                                       (ASSIGN (IDENTIFIER L) (IDENTIFIER $L_1362))
                                                                       (IDENTIFIER $C_1360)))))))
                                            (IDENTIFIER $C_1360))
                                           ()))
                                         (STATEMENT (RETURN (IDENTIFIER $R_1359))))))))))))
 ())
