#| -*-Scheme-*-

Copyright (C) 2019, 2020, 2021 Chris Hanson and Gerald Jay Sussman

This file is part of SDF.  SDF is software supporting the book
"Software Design for Flexibility", by Chris Hanson and Gerald Jay
Sussman.

SDF is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

SDF is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with SDF.  If not, see <https://www.gnu.org/licenses/>.

|#

;;; Object types for Adventure game

(define thing:location
  (make-property 'location
                 'predicate (lambda (x) (container? x))))

(define thing?
  (make-type 'thing (list thing:location)))
(set-predicate<=! thing? object?)

(define make-thing
  (type-instantiator thing?))

(define get-location
  (property-getter thing:location thing?))

(define-generic-procedure-handler set-up! (match-args thing?)
  (lambda (super thing)
    (super thing)
    (add-thing! (get-location thing) thing)))

(define-generic-procedure-handler tear-down! (match-args thing?)
  (lambda (super thing)
    (remove-thing! (get-location thing) thing)
    (super thing)))

(define-generic-procedure-handler send-message!
  (match-args message? thing?)
  (lambda (message thing)
    #f))

;;; Containers

(define container:things
  (make-property 'things
                 'predicate (is-list-of thing?)
                 'default-value '()))

(define container?
  (make-type 'container (list container:things)))
(set-predicate<=! container? object?)

(define get-things
  (property-getter container:things container?))

(define add-thing!
  (property-adder container:things container? thing?))

(define remove-thing!
  (property-remover container:things container? thing?))

;;; Exits

(define exit:from
  (make-property 'from
                 'predicate (lambda (x) (place? x))))

(define exit:to
  (make-property 'to
                 'predicate (lambda (x) (place? x))))

(define exit:direction
  (make-property 'direction
                 'predicate direction?))

(define exit?
  (make-type 'exit (list exit:from exit:to exit:direction)))
(set-predicate<=! exit? object?)

(define make-exit
  (type-instantiator exit?))

(define get-from
  (property-getter exit:from exit?))

(define get-to
  (property-getter exit:to exit?))

(define get-direction
  (property-getter exit:direction exit?))

(define-generic-procedure-handler set-up! (match-args exit?)
  (lambda (super exit)
    (super exit)
    (add-exit! (get-from exit) exit)))

;;; Places

(define place:vistas
  (make-property 'vistas
                 'predicate (lambda (x)
                              (and (n:list? x) (every place? x)))
                 'default-value '()))

(define place:exits
  (make-property 'exits
                 'predicate (lambda (x)
                              (and (n:list? x) (every place? x)))
                 'default-value '()))

(define place?
  (make-type 'place (list place:vistas place:exits)))
(set-predicate<=! place? container?)

(define make-place
  (type-instantiator place?))

(define get-vistas
  (property-getter place:vistas place?))

(define add-vista!
  (property-adder place:vistas place? place?))

(define get-exits
  (property-getter place:exits place?))

(define add-exit!
  (property-adder place:exits place? exit?))

(define (find-exit-in-direction direction place)
  (find (lambda (exit)
          (eqv? (get-direction exit) direction))
        (get-exits place)))

(define (people-in-place place)
  (filter person? (get-things place)))

(define (things-in-place place)
  (remove person? (get-things place)))

(define (all-things-in-place place)
  (append (things-in-place place)
          (append-map get-things (people-in-place place))))

(define (takeable-things place)
  (append (filter mobile-thing? (things-in-place place))
          (append-map get-things (people-in-place place))))

(define-generic-procedure-handler send-message!
  (match-args message? place?)
  (lambda (message place)
    (for-each (lambda (person)
                (send-message! message person))
              (people-in-place place))))

;;; Mobile things

(define mobile-thing:origin
  (make-property 'origin
                 'predicate place?
                 'default-to-property thing:location))

(define mobile-thing?
  (make-type 'mobile-thing (list mobile-thing:origin)))
(set-predicate<=! mobile-thing? thing?)

(define make-mobile-thing
  (type-instantiator mobile-thing?))

(define set-location!
  (property-setter thing:location mobile-thing? container?))

(define get-origin
  (property-getter mobile-thing:origin mobile-thing?))

(define enter-place!
  (chaining-generic-procedure 'enter-place! 1
    (constant-generic-procedure-handler #f)))

(define enter-place-web!
  (chaining-generic-procedure 'enter-place-web! 2
    (constant-generic-procedure-handler #f)))

(define leave-place!
  (most-specific-generic-procedure 'leave-place! 1
    (constant-generic-procedure-handler #f)))

;;; People

(define full-health)
(set! full-health (* (random-number 10) 3))
(define (get-full-health)
  full-health)

(define person:health
  (make-property 'health
                 'predicate n:exact-integer?
                 'default-value (get-full-health)))

(define person:bag
  (make-property 'bag
                 'predicate (lambda (x) (bag? x))
                 'default-supplier
                 (lambda () (make-bag 'name 'my-bag))))

(define person?
  (make-type 'person (list person:health person:bag)))
(set-predicate<=! person? mobile-thing?)

(define get-health
  (property-getter person:health person?))

(define set-health!
  (property-setter person:health person? any-object?))

(define get-bag
  (property-getter person:bag person?))

(define-generic-procedure-handler set-up! (match-args person?)
  (lambda (super person)
    (super person)
    (set-holder! (get-bag person) person)))

(define-generic-procedure-handler get-things (match-args person?)
  (lambda (person)
    (get-things (get-bag person))))

(define-generic-procedure-handler enter-place!
  (match-args person?)
  (lambda (super person)
    (super person)
    (tell! (list person "enters" (get-location person))
              person)
    (let ((people (people-here person)))
      (if (n:pair? people)
          (tell! (append (list person "says:") (cons "Hi" people))
            person)))))

(define-generic-procedure-handler enter-place-web!
  (match-args person? port?)
  (lambda (super person port)
    (super person port)
    (narrate-web! (list person "enters" (get-location person))
              person
	      port)
    (let ((people (people-here person)))
      (if (n:pair? people)
          (tell-web! (append (list person "says:") (cons "Hi" people))
		     port
		     person)))))

(define (when-alive callback)
  (lambda (person)
    (if (n:> (get-health person) 0)
        (callback person))))

(define (people-here person)
  (delv person (people-in-place (get-location person))))

(define (things-here person)
  (things-in-place (get-location person)))

(define (vistas-here person)
  (get-vistas (get-location person)))

(define (exits-here person)
  (get-exits (get-location person)))

(define (peoples-things person)
  (append-map get-things (people-here person)))

(define (suffer! hits person)
  (guarantee n:exact-positive-integer? hits)
  (say! person (list "Ouch!" hits "hits is more than I want!"))
  (set-health! person (- (get-health person) hits))
  (if (< (get-health person) 1)
      (die! person)))

(define (fight! person client troll)
  (let* ((troll-rand-num (/ (get-full-health) 3))
	 (damage-dealt (* troll-rand-num (random-number 3))))
    (set-health! troll (- (get-health troll) damage-dealt))
    (tell-web! (list "You dealt" damage-dealt "to" (get-name troll)) client troll)
    (tell-web! (list (get-name troll) "has"
			   (get-health troll) "hits remaining") client troll)
    (if (< (get-health troll) 1)
	(die-troll troll client))
    (tick-web! (get-clock) client)))

(define (suffer-web! hits person client)
  (guarantee n:exact-positive-integer? hits)
  (say-web! person (list "Ouch!" hits "hits is more than I want!") client)
  (set-health! person (- (get-health person) hits))
  (if (< (get-health person) 1)
      (die-web! person client)))

(define (die! person)
  (for-each (lambda (thing)
              (drop-thing! thing person))
            (get-things person))
  (announce!
   '("An earth-shattering, soul-piercing scream is heard..."))
  (set-health! person 0)
  (move! person (get-heaven) person))

(define (die-web! person client)
  (for-each (lambda (thing)
              (drop-thing-web! thing person client))
            (get-things person))
  (tell-web!
   '("An earth-shattering, soul-piercing scream is heard...")
   client
   person)
  (set-health! person 0)
  (move-web! person (get-heaven) person client))

(define (resurrect! person health)
  (guarantee n:exact-positive-integer? health)
  (set-health! person health)
  (move! person (get-origin person) person))

;;; Bags

(define bag:holder
  (make-property 'holder
                 'predicate
                 (lambda (x) (or (not x) (person? x)))
                 'default-value #f))

(define bag?
  (make-type 'bag (list bag:holder)))
(set-predicate<=! bag? container?)

(define make-bag
  (type-instantiator bag?))

(define get-holder
  (property-getter bag:holder bag?))

(define set-holder!
  (property-setter bag:holder bag? person?))

;;; Autonomous people (non-player characters)

(define autonomous-agent:restlessness
  (make-property 'restlessness
                 'predicate bias?))

(define autonomous-agent:acquisitiveness
  (make-property 'acquisitiveness
                 'predicate bias?))

(define autonomous-agent?
  (make-type 'autonomous-agent
             (list autonomous-agent:restlessness
                   autonomous-agent:acquisitiveness)))
(set-predicate<=! autonomous-agent? person?)

(define get-restlessness
  (property-getter autonomous-agent:restlessness
                   autonomous-agent?))

(define get-acquisitiveness
  (property-getter autonomous-agent:acquisitiveness
                   autonomous-agent?))

(define-generic-procedure-handler set-up!
  (match-args autonomous-agent?)
  (lambda (super agent)
    (super agent)
    (register-with-clock! agent (get-clock))))

(define-generic-procedure-handler tear-down!
  (match-args autonomous-agent?)
  (lambda (super agent)
    (unregister-with-clock! agent (get-clock))
    (super agent)))

(define (move-and-take-stuff-web! agent client)
  (if (flip-coin (get-restlessness agent))
      (move-somewhere! agent))
  (if (flip-coin (get-acquisitiveness agent))
      (take-something! agent)))

(define (move-somewhere! agent)
  (let ((exit (random-choice (exits-here agent))))
    (if exit
        (take-exit! exit agent))))

(define (take-something! agent)
  (let ((thing
         (random-choice (append (things-here agent)
                                (peoples-things agent)))))
    (if thing
        (take-thing! thing agent))))

(define-clock-handler-web autonomous-agent? port? move-and-take-stuff-web!)

;;; Students

(define student?
  (make-type 'student '()))
(set-predicate<=! student? autonomous-agent?)

(define make-student
  (type-instantiator student?))

;;; House masters

(define house-master:irritability
  (make-property 'irritability
                 'predicate bias?))

(define house-master?
  (make-type 'house-master (list house-master:irritability)))
(set-predicate<=! house-master? autonomous-agent?)

(define make-house-master
  (type-instantiator house-master?))

(define get-irritability
  (property-getter house-master:irritability house-master?))

(define (irritate-students-web! master client)
  (let ((students (filter student? (people-here master))))
    (if (flip-coin (get-irritability master))
        (if (n:pair? students)
            (begin
              (say-web! master
                    '("What are you doing still up?"
                      "Everyone back to their rooms!") client)
              (for-each (lambda (student)
                          (narrate-web! (list student "goes home to"
                                          (get-origin student))
                                    student client)
                          (move! student
                                 (get-origin student)
                                 student))
                        students))
            (say-web! master
                      '("Grrr... When I catch those students...")
		      client))
        (if (n:pair? students)
            (say-web! master
                      '("I'll let you off this once...")
		      client)))))

(define-clock-handler-web house-master? port? irritate-students-web!)

;;; Trolls

(define troll:hunger
  (make-property 'hunger
                 'predicate bias?))

(define troll?
  (make-type 'troll (list troll:hunger)))
(set-predicate<=! troll? autonomous-agent?)

(define make-troll
  (type-instantiator troll?))

(define get-hunger
  (property-getter troll:hunger troll?))

(define (eat-people! troll)
  (if (flip-coin (get-hunger troll))
      (let ((people (people-here troll)))
        (if (n:null? people)
            (tell! (list (possessive troll) "belly rumbles")
                       troll)
            (let ((victim (random-choice people)))
              (tell! (list troll "takes a bite out of" victim)
                         troll)
              (suffer! (random-number 3) victim))))))

(define (eat-people-web! troll client)
  (if (flip-coin (get-hunger troll))
      (let ((people (people-here troll)))
	(if (n:null? people)
	    (if (equal? (get-location troll) (get-location my-avatar))
			 (narrate! (list (possessive troll) "belly rumbles")
		       troll))
	    (let ((victim (random-choice people))
		  (victim-rand-num (/ (get-full-health) 3)))
	      (if (equal? (get-location troll) (get-location my-avatar))
		  (narrate-web! (list troll "takes a bite out of" victim)
			 troll client))
	      (suffer-web! (* victim-rand-num (random-number 3)) victim client))))))
			 
(define (die-troll troll client)
  (tell-web! (list (get-name troll) "is now in heaven.") client troll)
  (move-web! troll (get-heaven) troll client)
  (if (every (lambda (x) (eqv? (get-heaven) (get-location x)))
	     all-trolls)
      (tell-web! (list "Congrats! You have won the adventure. All the trolls are in heaven. You may now roam happily ever after...") client troll)))


(define-clock-handler troll? eat-people!)
(define-clock-handler-web troll? port? eat-people-web!)



;;; Avatars

(define avatar:screen
  (make-property 'screen
                 'predicate screen?))
(define avatar:log
  (make-property 'log
		 'predicate (is-list-of any-object?)
		 'default-value '()))

(define avatar?
  (make-type 'avatar (list avatar:screen avatar:log)))
(set-predicate<=! avatar? person?)

(define make-avatar
  (type-instantiator avatar?))

(define get-screen
  (property-getter avatar:screen avatar?))

(define get-log
  (property-getter avatar:log avatar?))

(define add-log
  (property-adder avatar:log avatar? any-object?))

(define set-log!
  (property-setter avatar:log avatar? any-object?))

(define-generic-procedure-handler send-message!
  (match-args message? avatar?)
  (lambda (message avatar)
    (send-message! message (get-screen avatar))))

(define-generic-procedure-handler enter-place!
  (match-args avatar?)
  (lambda (super avatar)
    (super avatar)
    (look-around avatar)
    (tick-web! (get-clock) port)))

(define-generic-procedure-handler enter-place-web!
  (match-args avatar? port?)
  (lambda (super avatar port)
    (super avatar port)
    (if (and (eqv? (get-location avatar) (get-medical-center))
	     (< (get-health avatar) (get-full-health)))
	(begin
	  (resurrect! avatar (get-full-health))
	  (tell-web! (list avatar "healed to full health:" (get-health avatar)) port avatar))
	())
    (look-around-web avatar port)
    (tick-web! (get-clock) port)))


(define (look-around avatar)
  (tell! (list "You are in" (get-location avatar))
         avatar)
  (let ((my-things (get-things avatar)))
    (if (n:pair? my-things)
        (tell! (cons "Your bag contains:" my-things)
               avatar)))
  (let ((things
         (append (things-here avatar)
                 (people-here avatar))))
    (if (n:pair? things)
        (tell! (cons "You see here:" things)
               avatar)))
  (let ((vistas (vistas-here avatar)))
    (if (n:pair? vistas)
        (tell! (cons "You can see:" vistas)
               avatar)))
  (tell! (let ((exits (exits-here avatar)))
           (if (n:pair? exits)
               (cons "You can exit:"
                     (map get-direction exits))
               '("There are no exits..."
                 "you are dead and gone to heaven!")))
         avatar))

(define (look-around-web avatar client)
  (set-log! avatar '())
  (tell-web! (list "You are in" (get-location avatar)) client avatar)
  (add-to-log (list "You are in" (get-location avatar)) avatar)
  (let ((my-things (get-things avatar)))
    (if (n:pair? my-things)
	(begin
	  (tell-web! (cons "Your bag contains:" my-things) client avatar)
	  (add-to-log (cons "Your bag contains:" my-things) avatar))))
  (let ((things (append (things-here avatar)
			(people-here avatar))))
    (if (n:pair? things)
	(begin
	  (tell-web! (cons "You see here:" things)
		     client
		     avatar)
	  (add-to-log (cons "You see here:" things) avatar))))
  (let ((vistas (vistas-here avatar)))
    (if (n:pair? vistas)
	(begin
	  (tell-web! (cons "You can see:" vistas) client avatar)
	  (add-to-log (cons "You can see:" vistas) avatar))))
  (tell-web! (let ((exits (exits-here avatar)))
	       (if (n:pair? exits)
		   (cons "You can exit:"
		     (map get-direction exits))
		   '("There are no exits..."
		     "you are dead and gone to heaven!")))
	     client
	     avatar)
  (add-to-log (let ((exits (exits-here avatar)))
	       (if (n:pair? exits)
		   (cons "You can exit:"
			 (map get-direction exits))
		   '("There are no exits..."
		     "you are dead and gone to heaven!")))
	     avatar))

;;; Motion

(define (take-thing! thing person)
  (move! thing (get-bag person) person))

(define (take-thing-web! thing person client)
  (move-web! thing (get-bag person) person client))

(define (drop-thing! thing person)
  (move! thing (get-location person) person))

(define (drop-thing-web! thing person client)
  (move-web! thing (get-location person) person client))

(define (take-exit-web! exit mobile-thing client)
  (generic-move-web! mobile-thing
                 (get-from exit)
                 (get-to exit)
                 mobile-thing
                 client))

(define (take-exit! exit mobile-thing)
  (generic-move! mobile-thing
                 (get-from exit)
                 (get-to exit)
                 mobile-thing))

(define (move! thing destination actor)
  (generic-move! thing
                 (get-location thing)
                 destination
                 actor))

(define (move-web! thing destination actor client)
  (generic-move-web! thing
                 (get-location thing)
                 destination
                 actor
		 client))

(define generic-move!
  (most-specific-generic-procedure 'generic-move! 4 #f))

(define generic-move-web!
  (most-specific-generic-procedure 'generic-move-web! 5 #f))

;;; TODO: guarantee that THING is in FROM.
;;; Also that the people involved are local.

;; coderef: generic-move:default
(define-generic-procedure-handler generic-move!
  (match-args thing? container? container? person?)
  (lambda (thing from to actor)
    (tell! (list thing "is not movable")
           actor)))

;; coderef: generic-move:steal
(define-generic-procedure-handler generic-move!
  (match-args mobile-thing? bag? bag? person?)
  (lambda (mobile-thing from to actor)
    (let ((former-holder (get-holder from))
          (new-holder (get-holder to)))
      (cond ((eqv? from to)
             (tell! (list new-holder "is already carrying"
                          mobile-thing)
                    actor))
            ((eqv? actor former-holder)
             (tell! (list actor
                             "gives" mobile-thing
                             "to" new-holder)
                       actor))
            ((eqv? actor new-holder)
             (tell! (list actor
                             "takes" mobile-thing
                             "from" former-holder)
                       actor))
            (else
             (tell! (list actor
                             "takes" mobile-thing
                             "from" former-holder
                             "and gives it to" new-holder)
                       actor)))
      (if (not (eqv? actor former-holder))
          (say! former-holder (list "Yaaaah! I am upset!")))
      (if (not (eqv? actor new-holder))
          (say! new-holder (list "Whoa! Where'd you get this?")))
      (if (not (eqv? from to))
          (move-internal! mobile-thing from to)))))

;; coderef: generic-move:take
(define-generic-procedure-handler generic-move!
  (match-args mobile-thing? place? bag? person?)
  (lambda (mobile-thing from to actor)
    (let ((new-holder (get-holder to)))
      (cond ((eqv? actor new-holder)
             (tell! (list actor
                             "picks up" mobile-thing)
                       actor))
            (else
             (tell! (list actor
                             "picks up" mobile-thing
                             "and gives it to" new-holder)
                       actor)))
      (if (not (eqv? actor new-holder))
          (say! new-holder (list "Whoa! Thanks, dude!")))
      (move-internal! mobile-thing from to))))

;; coderef: generic-move:drop
(define-generic-procedure-handler generic-move!
  (match-args mobile-thing? bag? place? person?)
  (lambda (mobile-thing from to actor)
    (let ((former-holder (get-holder from)))
      (cond ((eqv? actor former-holder)
             (tell! (list actor
                             "drops" mobile-thing)
                       actor))
            (else
             (tell! (list actor
                             "takes" mobile-thing
                             "from" former-holder
                             "and drops it")
                       actor)))
      (if (not (eqv? actor former-holder))
          (say! former-holder
                (list "What did you do that for?")))
      (move-internal! mobile-thing from to))))

(define-generic-procedure-handler generic-move!
  (match-args mobile-thing? place? place? person?)
  (lambda (mobile-thing from to actor)
    (cond ((eqv? from to)
           (tell! (list mobile-thing "is already in" from)
                  actor))
          (else
           (tell! (list "How do you propose to move"
                        mobile-thing
                        "without carrying it?")
                  actor)))))

;; coderef: generic-move:person
(define-generic-procedure-handler generic-move!
  (match-args person? place? place? person?)
  (lambda (person from to actor)
    (let ((exit (find-exit from to)))
      (cond ((or (eqv? from (get-heaven))
                 (eqv? to (get-heaven)))
             (move-internal! person from to))
            ((not exit)
             (tell! (list "There is no exit from" from
                          "to" to)
                    actor))
            ((eqv? person actor)
             (tell! (list person "leaves via the"
                             (get-direction exit) "exit")
                       from)
             (move-internal! person from to))
            (else
             (tell! (list "You can't force"
                          person
                          "to move!")
                    actor))))))

;; coderef: generic-move-web:default
(define-generic-procedure-handler generic-move-web!
  (match-args thing? container? container? person? port?)
  (lambda (thing from to actor port)
    (tell-web! (list thing "is not movable")
               port
	       actor)))

;; coderef: generic-move:steal
(define-generic-procedure-handler generic-move-web!
  (match-args mobile-thing? bag? bag? person? port?)
  (lambda (mobile-thing from to actor port)
    (let ((former-holder (get-holder from))
          (new-holder (get-holder to)))
      (cond ((eqv? from to)
             (tell-web! (list new-holder "is already carrying"
                          mobile-thing)
			port
			actor))
            ((eqv? actor former-holder)
             (tell-web! (list actor
                             "gives" mobile-thing
                             "to" new-holder)
			port
			actor))
            ((eqv? actor new-holder)
             (tell-web! (list actor
                             "takes" mobile-thing
                             "from" former-holder)
			port
			actor))
            (else
             (tell-web! (list actor
                             "takes" mobile-thing
                             "from" former-holder
                             "and gives it to" new-holder)
			port
			actor)))
      (if (not (eqv? actor former-holder))
          (say-web! former-holder (list "Yaaaah! I am upset!") port))
      (if (not (eqv? actor new-holder))
          (say-web! new-holder (list "Whoa! Where'd you get this?") port))
      (if (not (eqv? from to))
          (move-internal-web! mobile-thing from to port actor)))))

;; coderef: generic-move-web:take
(define-generic-procedure-handler generic-move-web!
  (match-args mobile-thing? place? bag? person? port?)
  (lambda (mobile-thing from to actor port)
    (let ((new-holder (get-holder to)))
      (cond ((eqv? actor new-holder)
             (tell-web! (list actor
                             "picks up" mobile-thing)
			port
			actor))
            (else
             (tell-web! (list actor
                             "picks up" mobile-thing
                             "and gives it to" new-holder)
			port
			actor)))
      (if (not (eqv? actor new-holder))
          (say-web! new-holder (list "Whoa! Thanks, dude!") port))
      (move-internal-web! mobile-thing from to port actor))))

;; coderef: generic-move-web:drop
(define-generic-procedure-handler generic-move-web!
  (match-args mobile-thing? bag? place? person? port?)
  (lambda (mobile-thing from to actor port)
    (let ((former-holder (get-holder from)))
      (cond ((eqv? actor former-holder)
             (tell-web! (list actor
                             "drops" mobile-thing)
			port
			actor))
            (else
             (tell-web! (list actor
                             "takes" mobile-thing
                             "from" former-holder
                             "and drops it")
			port
			actor)))
      (if (not (eqv? actor former-holder))
          (say-web! former-holder
                    (list "What did you do that for?")
		    port))
      (move-internal-web! mobile-thing from to port actor))))

(define-generic-procedure-handler generic-move-web!
  (match-args mobile-thing? place? place? person? port?)
  (lambda (mobile-thing from to actor port)
    (cond ((eqv? from to)
           (tell-web! (list mobile-thing "is already in" from)
		      port
		      actor))
          (else
           (tell-web! (list "How do you propose to move"
                        mobile-thing
                        "without carrying it?")
		      port
		      actor)))))

;; coderef: generic-move-web:person
(define-generic-procedure-handler generic-move-web!
  (match-args person? place? place? person? port?)
  (lambda (person from to actor port)
    (let ((exit (find-exit from to)))
      (cond ((or (eqv? from (get-heaven))
                 (eqv? to (get-heaven)))
             (move-internal-web! person from to port actor))
            ((not exit)
             (tell-web! (list "There is no exit from" from
                          "to" to)
			port
			actor))
            ((eqv? person actor)
             (narrate-web! (list person "leaves via the"
                             (get-direction exit) "exit")
			   from
			   port)
             (move-internal-web! person from to port actor))
            (else
             (tell-web! (list "You can't force"
                          person
                          "to move!")
			port
			actor))))))

(define (find-exit from to)
  (find (lambda (exit)
          (and (eqv? (get-from exit) from)
               (eqv? (get-to exit) to)))
        (get-exits from)))

(define (move-internal! mobile-thing from to)
  (leave-place! mobile-thing)
  (remove-thing! from mobile-thing)
  (set-location! mobile-thing to)
  (add-thing! to mobile-thing)
  (enter-place! mobile-thing))

(define (move-internal-web! mobile-thing from to client actor)
  (leave-place! mobile-thing)
  (remove-thing! from mobile-thing)
  (set-location! mobile-thing to)
  (add-thing! to mobile-thing)
  (enter-place-web! mobile-thing client))
