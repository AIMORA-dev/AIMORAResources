      SUBROUTINE AIMORA_GOLDEN_TAPE_INIT
      IMPLICIT REAL*8 (A-H, O-Z) ,
     1      INTEGER*4 (I-N)
      INCLUDE  'BLKCOM.FOR;/NOLIST'
      CHARACTER*512 DIRNAM, FILNAM
      INTEGER*4 LDIR, ISTAT
      INTEGER*4 IBUF(24)
      LOGICAL DONE
      SAVE DONE
      DATA DONE /.FALSE./
      IF (DONE) RETURN
      CALL GET_ENVIRONMENT_VARIABLE('EMTP_GOLDEN_TAPE_DIR',
     1     DIRNAM, LDIR, ISTAT)
      IF (ISTAT .NE. 0) RETURN
      IF (LDIR .LE. 0) RETURN
      DONE = .TRUE.
      IF (DIRNAM(LDIR:LDIR) .EQ. '/') THEN
         FILNAM = DIRNAM(1:LDIR) // 'main00_startup_i4.bin'
      ELSE
         FILNAM = DIRNAM(1:LDIR) // '/main00_startup_i4.bin'
      ENDIF
      IBUF(1) = LUNIT1
      IBUF(2) = LUNIT2
      IBUF(3) = LUNIT3
      IBUF(4) = LUNIT4
      IBUF(5) = LUNIT5
      IBUF(6) = LUNIT6
      IBUF(7) = LUNIT7
      IBUF(8) = LUNIT8
      IBUF(9) = LUNIT9
      IBUF(10) = LUNT10
      IBUF(11) = LUNT11
      IBUF(12) = LUNT12
      IBUF(13) = LUNT13
      IBUF(14) = LUNT14
      IBUF(15) = LUNT15
      IBUF(16) = LLBUFF
      IBUF(17) = KOL132
      IBUF(18) = NCHAIN
      IBUF(19) = LASTOV
      IBUF(20) = KILL
      IBUF(21) = IPRSUP
      IBUF(22) = NUMDCD
      IBUF(23) = M4PLOT
      IBUF(24) = 0
      OPEN (UNIT=97, FILE=FILNAM, FORM='UNFORMATTED',
     1      ACCESS='STREAM', STATUS='REPLACE', ACTION='WRITE')
      WRITE (97) IBUF
      CLOSE (97)
      RETURN
      END

      SUBROUTINE AIMORA_RC2_TAPE_STAGE ( STAGE )
      IMPLICIT REAL*8 (A-H, O-Z) ,
     1      INTEGER*4 (I-N)
      INCLUDE  'BLKCOM.FOR;/NOLIST'
      INCLUDE  'TACSTO.INS'
      INCLUDE  'LABCOM.INS'
      INTEGER*4 STAGE
      CHARACTER*512 DIRNAM, FILI4, FILF8
      CHARACTER*32 BASEI, BASEF
      INTEGER*4 LDIR, ISTAT, LBASE
      INTEGER*4 IBUF(64)
      REAL*8 RBUF(64)
      LOGICAL WROTE
      DIMENSION WROTE(4)
      SAVE WROTE
      DATA WROTE /4*.FALSE./
      IF (STAGE .LT. 1 .OR. STAGE .GT. 4) RETURN
      IF (WROTE(STAGE)) RETURN
      CALL GET_ENVIRONMENT_VARIABLE('EMTP_GOLDEN_TAPE_DIR',
     1     DIRNAM, LDIR, ISTAT)
      IF (ISTAT .NE. 0) RETURN
      IF (LDIR .LE. 0) RETURN
      WROTE(STAGE) = .TRUE.
      IF (STAGE .EQ. 1) THEN
         BASEI = 'rc2_init_core_i4.bin'
         BASEF = 'rc2_init_core_f8.bin'
         LBASE = 20
      ELSE IF (STAGE .EQ. 2) THEN
         BASEI = 'rc2_t0_core_i4.bin'
         BASEF = 'rc2_t0_core_f8.bin'
         LBASE = 18
      ELSE IF (STAGE .EQ. 3) THEN
         BASEI = 'rc2_dt_core_i4.bin'
         BASEF = 'rc2_dt_core_f8.bin'
         LBASE = 18
      ELSE
         BASEI = 'rc2_two_dt_core_i4.bin'
         BASEF = 'rc2_two_dt_core_f8.bin'
         LBASE = 22
      ENDIF
      IF (DIRNAM(LDIR:LDIR) .EQ. '/') THEN
         FILI4 = DIRNAM(1:LDIR) // BASEI(1:LBASE)
         FILF8 = DIRNAM(1:LDIR) // BASEF(1:LBASE)
      ELSE
         FILI4 = DIRNAM(1:LDIR) // '/' // BASEI(1:LBASE)
         FILF8 = DIRNAM(1:LDIR) // '/' // BASEF(1:LBASE)
      ENDIF
      DO 100 I = 1, 64
         IBUF(I) = 0
         RBUF(I) = 0.0D0
  100 CONTINUE
      IBUF(1) = STAGE
      IBUF(2) = NCHAIN
      IBUF(3) = LASTOV
      IBUF(4) = KILL
      IBUF(5) = IPRSUP
      IBUF(6) = ISTEP
      IBUF(7) = KCONST
      IBUF(8) = KSWTCH
      IBUF(9) = IT
      IBUF(10) = NTOT
      IBUF(11) = IBR
      IBUF(12) = LAST
      IBUF(13) = NPOWER
      IBUF(14) = MAXPE
      IBUF(15) = FROM
      IBUF(16) = TO
      IBUF(17) = IPTR
      IBUF(18) = RPTR
      IBUF(19) = SPTR
      IBUF(20) = ENV
      IBUF(21) = USEENV
      IBUF(22) = DATENV
      IBUF(23) = BASE3
      IBUF(24) = BASE7
      IBUF(25) = NEXTSW(1)
      IBUF(26) = KODE(1)
      IBUF(27) = LSTAT(1)
      IBUF(28) = LSTAT(2)
      IBUF(29) = LSTAT(3)
      IBUF(30) = LSTAT(4)
      RBUF(1) = T
      RBUF(2) = DELTAT
      RBUF(3) = TMAX
      RBUF(4) = ETIME
      RBUF(5) = ESTEP
      RBUF(6) = ESTOP
      RBUF(7) = STPT
      IF (BASE3 .GT. 0 .AND. BASE3 + 8 .LE. 9000) THEN
         RBUF(8) = RSTO(BASE3+8)
      ENDIF
      IF (BASE7 .GT. 0 .AND. BASE7 + 1 .LE. 9000) THEN
         RBUF(9) = RSTO(BASE7+1)
      ENDIF
      RBUF(10) = VOLTBC(1)
      RBUF(11) = VOLTI(1)
      RBUF(12) = VOLTI(2)
      RBUF(13) = VOLT(1)
      RBUF(14) = BVALUE(1)
      RBUF(15) = HISTQ(1)
      RBUF(16) = XMAX(1)
      IF (RPTR .GT. 0 .AND. RPTR .LE. 9000) THEN
         RBUF(17) = RSTO(RPTR)
      ENDIF
      OPEN (UNIT=98, FILE=FILI4, FORM='UNFORMATTED',
     1      ACCESS='STREAM', STATUS='REPLACE', ACTION='WRITE')
      WRITE (98) IBUF
      CLOSE (98)
      OPEN (UNIT=99, FILE=FILF8, FORM='UNFORMATTED',
     1      ACCESS='STREAM', STATUS='REPLACE', ACTION='WRITE')
      WRITE (99) RBUF
      CLOSE (99)
      CALL AIMORA_TACS_SOLVUM_TAPE_STAGE ( STAGE )
      RETURN
      END

      SUBROUTINE AIMORA_RC2_TAPE_STEP_SAMPLE
      IMPLICIT REAL*8 (A-H, O-Z) ,
     1      INTEGER*4 (I-N)
      INTEGER*4 COUNT
      SAVE COUNT
      DATA COUNT /0/
      IF (COUNT .GE. 3) RETURN
      COUNT = COUNT + 1
      CALL AIMORA_RC2_TAPE_STAGE ( COUNT + 1 )
      RETURN
      END

      SUBROUTINE AIMORA_TACS_SOLVUM_TAPE_PATH ( BASE, FILNAM, OK )
      IMPLICIT REAL*8 (A-H, O-Z) ,
     1      INTEGER*4 (I-N)
      CHARACTER*(*) BASE
      CHARACTER*512 DIRNAM, FILNAM
      INTEGER*4 LDIR, ISTAT, LBASE
      LOGICAL OK
      OK = .FALSE.
      CALL GET_ENVIRONMENT_VARIABLE('EMTP_GOLDEN_TAPE_DIR',
     1     DIRNAM, LDIR, ISTAT)
      IF (ISTAT .NE. 0) RETURN
      IF (LDIR .LE. 0) RETURN
      LBASE = LEN(BASE)
  100 IF (LBASE .LE. 0) RETURN
      IF (BASE(LBASE:LBASE) .NE. ' ') GO TO 110
      LBASE = LBASE - 1
      GO TO 100
  110 IF (DIRNAM(LDIR:LDIR) .EQ. '/') THEN
         FILNAM = DIRNAM(1:LDIR) // BASE(1:LBASE)
      ELSE
         FILNAM = DIRNAM(1:LDIR) // '/' // BASE(1:LBASE)
      ENDIF
      OK = .TRUE.
      RETURN
      END

      SUBROUTINE AIMORA_TACS_SOLVUM_TAPE_WRITE_F8
     1     ( BASE, BUF, N )
      IMPLICIT REAL*8 (A-H, O-Z) ,
     1      INTEGER*4 (I-N)
      CHARACTER*(*) BASE
      CHARACTER*512 FILNAM
      REAL*8 BUF(*)
      LOGICAL OK
      IF (N .LE. 0) RETURN
      CALL AIMORA_TACS_SOLVUM_TAPE_PATH ( BASE, FILNAM, OK )
      IF (.NOT. OK) RETURN
      OPEN (UNIT=94, FILE=FILNAM, FORM='UNFORMATTED',
     1      ACCESS='STREAM', STATUS='REPLACE', ACTION='WRITE')
      WRITE (94) (BUF(I), I=1,N)
      CLOSE (94)
      RETURN
      END

      SUBROUTINE AIMORA_TACS_SOLVUM_TAPE_WRITE_I4
     1     ( BASE, IBUF, N )
      IMPLICIT REAL*8 (A-H, O-Z) ,
     1      INTEGER*4 (I-N)
      CHARACTER*(*) BASE
      CHARACTER*512 FILNAM
      INTEGER*4 IBUF(*)
      LOGICAL OK
      IF (N .LE. 0) RETURN
      CALL AIMORA_TACS_SOLVUM_TAPE_PATH ( BASE, FILNAM, OK )
      IF (.NOT. OK) RETURN
      OPEN (UNIT=93, FILE=FILNAM, FORM='UNFORMATTED',
     1      ACCESS='STREAM', STATUS='REPLACE', ACTION='WRITE')
      WRITE (93) (IBUF(I), I=1,N)
      CLOSE (93)
      RETURN
      END

      SUBROUTINE AIMORA_TACS_SOLVUM_TAPE_TACS3_CALL
      IMPLICIT REAL*8 (A-H, O-Z) ,
     1      INTEGER*4 (I-N)
      INTEGER*4 IBUF(4), COUNT
      SAVE COUNT
      DATA COUNT /0/
      COUNT = COUNT + 1
      IBUF(1) = COUNT
      IBUF(2) = 0
      IBUF(3) = 0
      IBUF(4) = 0
      CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_I4
     1     ( 'tacs_solvum_tacs3_call_count_i4.bin', IBUF, 4 )
      RETURN
      END

      SUBROUTINE AIMORA_TACS_SOLVUM_TAPE_SOLVUM_CALL
      IMPLICIT REAL*8 (A-H, O-Z) ,
     1      INTEGER*4 (I-N)
      INTEGER*4 IBUF(4), COUNT
      SAVE COUNT
      DATA COUNT /0/
      COUNT = COUNT + 1
      IBUF(1) = COUNT
      IBUF(2) = 0
      IBUF(3) = 0
      IBUF(4) = 0
      CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_I4
     1     ( 'tacs_solvum_solvum_call_count_i4.bin', IBUF, 4 )
      RETURN
      END

      SUBROUTINE AIMORA_TACS_SOLVUM_TAPE_STAGE ( STAGE )
      IMPLICIT REAL*8 (A-H, O-Z) ,
     1      INTEGER*4 (I-N)
      INCLUDE  'BLKCOM.FOR;/NOLIST'
      INCLUDE  'LABCOM.INS'
      INCLUDE  'TACSAR.FOR;/NOLIST'
      INCLUDE  'UMDECK.FOR;/NOLIST'
      INTEGER*4 STAGE
      INTEGER*4 IBUF(32)
      REAL*8 OUTBUF(2400)
      LOGICAL WROTE
      DIMENSION WROTE(4)
      SAVE WROTE
      DATA WROTE /4*.FALSE./
      IF (STAGE .LT. 1 .OR. STAGE .GT. 4) RETURN
      IF (WROTE(STAGE)) RETURN
      WROTE(STAGE) = .TRUE.
      DO 200 I = 1, 32
         IBUF(I) = 0
  200 CONTINUE
      IBUF(1) = STAGE
      IBUF(2) = NUK
      IBUF(3) = NSUP
      IBUF(4) = IOUTCS
      IBUF(5) = KXTCS
      IBUF(6) = KRSBLK
      IBUF(7) = KPRSUP
      IBUF(8) = KJOUT
      IBUF(9) = NUMUM
      IBUF(10) = NUMOUT
      IBUF(11) = NCLTOT
      IBUF(12) = LOOPSS(1)
      IBUF(13) = LOOPSS(8)
      IBUF(14) = ISTART
      IBUF(15) = ISTEP
      IBUF(16) = 0
      IF (NUK .GT. 0 .OR. NSUP .GT. 0 .OR. IOUTCS .GT. 0)
     1   IBUF(16) = 1
      IBUF(17) = 0
      IF (NUMUM .GT. 0 .OR. NUMOUT .GT. 0) IBUF(17) = 1
      IBUF(18) = 2400
      IBUF(19) = 30000
      IF (STAGE .EQ. 1) THEN
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_F8
     1        ( 'tacs_solvum_xtcs_init_f8.bin', XTCS, 2400 )
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_I4
     1        ( 'tacs_solvum_metadata_init_i4.bin', IBUF, 32 )
      ELSE IF (STAGE .EQ. 2) THEN
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_F8
     1        ( 'tacs_solvum_xtcs_t0_f8.bin', XTCS, 2400 )
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_I4
     1        ( 'tacs_solvum_metadata_t0_i4.bin', IBUF, 32 )
      ELSE IF (STAGE .EQ. 3) THEN
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_F8
     1        ( 'tacs_solvum_xtcs_dt_f8.bin', XTCS, 2400 )
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_I4
     1        ( 'tacs_solvum_metadata_dt_i4.bin', IBUF, 32 )
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_F8
     1        ( 'tacs_solvum_rsblk_dt_f8.bin', RSBLK, 2400 )
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_F8
     1        ( 'tacs_solvum_parsup_dt_f8.bin', PARSUP, 2400 )
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_F8
     1        ( 'tacs_solvum_limiter_state_dt_f8.bin', RSBLK, 2400 )
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_F8
     1        ( 'tacs_solvum_history_dt_f8.bin', PARSUP, 2400 )
         DO 300 I = 1, 2400
            OUTBUF(I) = 0.0D0
  300    CONTINUE
         OUTBUF(1) = IOUTCS
         IF (IOUTCS .GT. 0 .AND. KJOUT .GT. 0) THEN
            NOUT = IOUTCS
            IF (NOUT .GT. 2399) NOUT = 2399
            DO 310 I = 1, NOUT
               J = JOUT(KJOUT+I)
               IF (J .GT. 0) OUTBUF(I+1) = XTCS(KXTCS+J)
  310       CONTINUE
         ENDIF
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_F8
     1        ( 'tacs_solvum_output_dt_f8.bin', OUTBUF, 2400 )
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_F8
     1        ( 'tacs_solvum_solvum_state_dt_f8.bin', SPUM, 30000 )
         DO 320 I = 1, 2400
            OUTBUF(I) = 0.0D0
  320    CONTINUE
         OUTBUF(1) = NUMOUT
         IF (NUMOUT .GT. 0 .AND. IUUMOU .GT. 0) THEN
            NOUT = NUMOUT
            IF (NOUT .GT. 2399) NOUT = 2399
            DO 330 I = 1, NOUT
               OUTBUF(I+1) = SPUM(IUUMOU+I-1)
  330       CONTINUE
         ENDIF
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_F8
     1        ( 'tacs_solvum_solvum_output_dt_f8.bin', OUTBUF, 2400 )
      ELSE
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_F8
     1        ( 'tacs_solvum_xtcs_two_dt_f8.bin', XTCS, 2400 )
         CALL AIMORA_TACS_SOLVUM_TAPE_WRITE_I4
     1        ( 'tacs_solvum_metadata_two_dt_i4.bin', IBUF, 32 )
      ENDIF
      RETURN
      END
