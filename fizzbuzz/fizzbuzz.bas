    LET N = 1
400 GOSUB 500
    LET N = N + 1
    IF N <= 100 THEN GOTO 400
    END

500 IF N = N / 15 * 15 THEN GOTO 501
    IF N = N / 3 * 3 THEN GOTO 502
    IF N = N / 5 * 5 THEN GOTO 503
    PRINT N
    RETURN
501 PRINT "FizzBuzz"
    RETURN
502 PRINT "Fizz"
    RETURN
503 PRINT "Buzz"
    RETURN
