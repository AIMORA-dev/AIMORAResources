      SUBROUTINE EMTPID ( MON, IDAY, IYR )
C     Portable replacement for the VAX IDATE(MON,DAY,YEAR) call.
      INTEGER*2 MON, IDAY, IYR
      INTEGER VALUES(8)
      CALL DATE_AND_TIME ( VALUES=VALUES )
      MON = VALUES(2)
      IDAY = VALUES(3)
      IYR = MOD( VALUES(1), 100 )
      RETURN
      END

      SUBROUTINE EMTPTM ( CH )
C     Portable replacement for the VAX TIME(LOGICAL*1(8)) call.
      INTEGER*1 CH(8)
      INTEGER VALUES(8)
      CHARACTER*8 OUT
      CALL DATE_AND_TIME ( VALUES=VALUES )
      WRITE (OUT, 1000) VALUES(5), VALUES(6), VALUES(7)
 1000 FORMAT ( I2.2, '.', I2.2, '.', I2.2 )
      DO 1010 I = 1, 8
 1010 CH(I) = ICHAR( OUT(I:I) )
      RETURN
      END
