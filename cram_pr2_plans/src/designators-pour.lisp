;;;
;;; Copyright (c) 2016, Gayane Kazhoyan <kazhoyan@cs.uni-bremen.de>
;;; All rights reserved.
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions are met:
;;;
;;;     * Redistributions of source code must retain the above copyright
;;;       notice, this list of conditions and the following disclaimer.
;;;     * Redistributions in binary form must reproduce the above copyright
;;;       notice, this list of conditions and the following disclaimer in the
;;;       documentation and/or other materials provided with the distribution.
;;;     * Neither the name of the Institute for Artificial Intelligence/
;;;       Universitaet Bremen nor the names of its contributors may be used to
;;;       endorse or promote products derived from this software without
;;;       specific prior written permission.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
;;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;;; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;;; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
;;; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;;; POSSIBILITY OF SUCH DAMAGE.

(in-package :pr2-plans)

(defun append-pour-action-designator (action-designator ?arm
                                      ?left-pour-poses ?right-pour-poses
                                      ?left-tilt-pose ?right-tilt-pose
                                      ?left-retract-poses ?right-retract-poses)
  (case ?arm
    (:left (setf ?right-pour-poses nil
                 ?right-retract-poses nil
                 ?right-tilt-pose nil))
    (:right (setf ?left-pour-poses nil
                  ?left-retract-poses nil
                  ?left-tilt-pose nil)))
  ;; (setf ?left-grasp-poses (reverse ?left-grasp-poses))
  ;; (setf ?right-grasp-poses (reverse ?right-grasp-poses))
  (let* (;; (?minus-angle (- ?angle))
         (phases (list
                  (an action
                      (to my-approach)
                      (left ?left-pour-poses)
                      (right ?right-pour-poses))
                  ;; (an action
                  ;;     (to my-tilt-angle)
                  ;;     (left ?left-pour-poses)
                  ;;     (right ?right-pour-poses)
                  ;;     (angle ?angle))
                  (an action
                      (to my-tilt-to)
                      (left ?left-tilt-pose)
                      (right ?right-tilt-pose))
                  (an action
                      (to my-tilt-to)
                      (left ?left-pour-poses)
                      (right ?right-pour-poses))
                  (an action
                      (to my-retract)
                      (left ?left-retract-poses)
                      (right ?right-retract-poses)))))
    (copy-designator action-designator :new-description `((:phases ,phases)))))

;; (declaim (inline car-last))
(defun car-last (some-list)
  (if (listp some-list)
      (car (last some-list))
      some-list))

(def-fact-group pr2-pouring-plans (action-desig)

  (<- (action-desig ?action-designator (perform-phases-in-sequence ?updated-action-designator))
    (or (desig-prop ?action-designator (:to :my-pour))
        (desig-prop ?action-designator (:type :my-pouring)))
    (once (or (desig-prop ?action-designator (:arm ?arm))
              (equal ?arm (:left :right))))
    (desig-prop ?action-designator (:source ?source-designator))
    (current-designator ?source-designator ?current-source-designator)
    (desig-prop ?current-source-designator (:type ?source-type))
    (object-type-grasp ?source-type ?grasp)
    (desig-prop ?action-designator (:destination ?destination-designator))
    (current-designator ?destination-designator ?current-destination-designator)
    (lisp-fun get-object-pose ?current-destination-designator ?destination-pose)
    ;; so we have (an action (to pour) (destination (an object (pose ...) (type ...))))
    ;; now we need to add the phases with the corresponding via-points and angles
    ;; find the missing info
    (lisp-fun get-object-type-pour-pose ?source-type ?destination-pose :left ?grasp
              ?left-pour-pose)
    (lisp-fun get-object-type-pour-pose ?source-type ?destination-pose :right ?grasp
              ?right-pour-pose)
    ;;
    (lisp-fun get-object-type-grasp-pose ?source-type ?destination-pose :left ?grasp
              ?left-grasp-pose)
    (lisp-fun get-object-type-grasp-pose ?source-type ?destination-pose :right ?grasp
              ?right-grasp-pose)
    ;;
    (lisp-fun get-object-type-pregrasp-pose ?source-type ?left-grasp-pose :left ?grasp
              ?left-retract-pose)
    (lisp-fun get-object-type-pregrasp-pose ?source-type ?right-grasp-pose :right ?grasp
              ?right-retract-pose)
    ;;
    (lisp-fun cram-math:degrees->radians 100 ?angle)
    (lisp-fun get-tilted-pose ?left-pour-pose ?angle :left ?grasp ?left-tilt-pose)
    (lisp-fun get-tilted-pose ?right-pour-pose ?angle :right ?grasp ?right-tilt-pose)
    ;; create new designator with updated appended action-description
    (lisp-fun append-pour-action-designator ?action-designator ?arm
              ?left-pour-pose ?right-pour-pose
              ?left-tilt-pose ?right-tilt-pose
              ?left-retract-pose ?right-retract-pose
              ?updated-action-designator))

  (<- (action-desig ?action-designator (move-arms-in-sequence ?left-poses ?right-poses))
    (desig-prop ?action-designator (:to :my-approach))
    (once (or (desig-prop ?action-designator (:left ?left-poses))
              (equal ?left-poses nil)))
    (once (or (desig-prop ?action-designator (:right ?right-poses))
              (equal ?right-poses nil))))

  ;; (<- (action-desig ?action-designator (tilt ?left-goal-pose ?right-goal-pose))
  ;;   (desig-prop ?action-designator (:to :my-tilt-angle))
  ;;   (desig-prop ?action-designator (:left ?left-initial-poses))
  ;;   (desig-prop ?action-designator (:right ?right-initial-poses))
  ;;   (desig-prop ?action-designator (:angle ?angle))
  ;;   (lisp-fun get-tilted-pose ?left-initial-poses ?angle ...))

  (<- (action-desig ?action-designator (move-arms-in-sequence ?left-last-pose ?right-last-pose))
    (desig-prop ?action-designator (:to :my-tilt-to))
    (desig-prop ?action-designator (:left ?left-poses))
    (desig-prop ?action-designator (:right ?right-poses))
    (lisp-fun car-last ?left-poses ?left-last-pose)
    (lisp-fun car-last ?right-poses ?right-last-pose)))