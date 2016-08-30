#!/usr/bin/guile -s
!#

(use-modules (ice-9 ftw) (ice-9 pretty-print) 
             (ice-9 match) (srfi srfi-1) (ice-9 getopt-long))

; Directory checksum structure:
; 
; ( ((path . "./dir1") (cksum (dir-size . 9586)))
;   ((path . "./dir2/another") (cksum (dir-size . 4108)))
;   ((path . "./dir2/other") (cksum (dir-size . 4100)))
;   ((path . "./dir2/tmp") (cksum (dir-size . 4100)))
;   ... )
;

(define (flat-print lst-dir-paths)
  (let ((print-group
          (lambda (lst) 
            (map displayln lst)
            (displayln " "))))
    (map print-group lst-dir-paths)))

; Options
(define *OPT-MAX-DIR-SZ* (* 512 1024))   ; Ignore directories < this many bytes
(define *OPT-PRINT-FUNC* flat-print)     ; Function used to print the output
;(define *OPT-PRINT-FUNC* pretty-print)  ; Uncomment this for more lispy output

(define (benchmark-timer fn fnname)
  (let* ((start (tms:clock (times)))
         (result (fn))
         (finished (- (tms:clock (times)) start)))
    (format (current-output-port) "'~a' finished in ~a ns (~a sec)~%" 
            fnname 
            finished 
            (exact->inexact (/ finished (expt 10 9))))
    result))

(define *OUT* (current-output-port))

(define fs-slash-chr 
  (string-ref file-name-separator-string 0))

(define (displayln a)
  (display a) (newline))

(define (get-cksum s)
  (assq-ref s 'cksum))

(define (get-path s)
  (assq-ref s 'path))

(define (get-from-cksum elem lst)
  (assq-ref (get-cksum lst) elem))

(define (get-dir-sz s)
  (get-from-cksum 'dir-size s))

(define (path-combine tail head)
  (string-append tail file-name-separator-string head))

(define (string-trim-path-slash str)
  (if (equal? (string fs-slash-chr) str)
    str
    (string-trim-right str fs-slash-chr)))

(define (less-than-sort-cksums Y X)
  (let ((sizeY (get-from-cksum 'dir-size Y))
        (sizeX (get-from-cksum 'dir-size X)))
    (> sizeY sizeX)))

(define (get-culm-dir-size tree)
  (match tree
    ((file stat)
     (if (boolean? stat) 
       0
       (stat:size stat)))
    ((dir stat children ...)
     (apply + (stat:size stat) (map get-culm-dir-size children))))) 

(define (over-max-dir-sz? sz)
  (> sz *OPT-MAX-DIR-SZ*))

(define (entry-over-max-dir-sz? ent)
  (over-max-dir-sz? (get-dir-sz ent)))

; Return a list of lists of duplicate directory paths (based on cksum)
(define (get-dup-dirs 
          dirs-with-cksum     ; Pre-sorted based on directory size
          prev-dup-dir-paths) ; List of paths being build
  (let*  
    ((pivot-dir (car dirs-with-cksum)) ; This directory

     (same-cksum-as-pivot? 
       (lambda (testdir)
         (equal? 
           (get-cksum pivot-dir) 
           (get-cksum testdir))))

    ; List of directory paths with the same cksum as pivot-dir 
     (dup-dir-paths 
       (map get-path ; get paths from the structure
         (cons pivot-dir ; always include pivot-dir in lst
           (take-while  
             same-cksum-as-pivot? 
             (cdr dirs-with-cksum)))))

     (all-other-dirs 
       (list-tail dirs-with-cksum (length dup-dir-paths)))

    ; Don't list this directory if...
     (skip?  
       (or
         (= 1 (length dup-dir-paths))  ; pivot-dir has no duplicates
         (any (lambda (past-dir)       ; it is a sub directory of another duplicate
                (string-contains (get-path pivot-dir) (car past-dir)))
              prev-dup-dir-paths))))

    (cond 
      ((null? all-other-dirs) ; No more directories left!
       (if (> (length dup-dir-paths) 1)
         (cons dup-dir-paths prev-dup-dir-paths)
         prev-dup-dir-paths))
      (skip?                  ; Should we skip this series of directories?
       (get-dup-dirs all-other-dirs prev-dup-dir-paths))
      (else                   ; Keep scanning!
        (get-dup-dirs 
          all-other-dirs 
          (cons dup-dir-paths prev-dup-dir-paths))))))

; Is the file at the top of this tree a directory?
(define (tree-is-dir? tree)
  (let ((try-stat (cadr tree)))
    (if (boolean? try-stat)
      #f
      (eq? (stat:type try-stat) 'directory))))

; Generates a list of assoc lists consisting of a 'path and a 'cksum 
(define (tree->cksumlst tree path)
  (match tree
    ((dir stat children ...) 
     (let ((directories (filter tree-is-dir? children)))  ; We only recurse into directories
       (cons
         (list 
           (cons 'path path)
           (cons 'cksum (list (cons 'dir-size (get-culm-dir-size tree)))))
         (concatenate 
           (map 
             (lambda (new-tree) 
               (tree->cksumlst new-tree (path-combine path (car new-tree))))
             directories)))))))

; Maybe I'll someday get around to implementing these
;(define (print-help-and-exit)
;  (displayln "Usage: find-dups.scm [-v] [-s SIZE] [-p STYLE] [DIRECTORY]")
;  (displayln "-s SIZE     Directories below SIZE KB are ignored (default 512)")
;  (displayln "-p STYLE    Output style, may either be 'paren' or 'flat' (default 'flat')")
;  (displayln "-v          Verbose output (defualt off)")
;  (exit 1))


(define (main argv)

  (let* ((filepath (string-trim-path-slash (list-ref argv (1- (length argv)))))
        (_ (format *OUT* "Generating file system tree... [~a]~%" filepath))
        (file-tree (file-system-tree filepath))
        (_ (format *OUT* "Generating checksums... ~%") )
        (dirs-with-cksum (tree->cksumlst file-tree filepath))
        (_ (format *OUT* "Filtering... ~%"))
        (dirs-with-cksum (filter entry-over-max-dir-sz? dirs-with-cksum)))

      (displayln "Sorting...")

      (benchmark-timer 
        (lambda () (sort! dirs-with-cksum less-than-sort-cksums)) "sort!")

      (*OPT-PRINT-FUNC* (get-dup-dirs dirs-with-cksum '()))))

(main (command-line))
