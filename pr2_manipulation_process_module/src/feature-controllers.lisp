;;; Copyright (c) 2013, Georg Bartels <georg.bartels@cs.uni-bremen.de>
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
;;;     * Neither the name of the Intelligent Autonomous Systems Group/
;;;       Technische Universitaet Muenchen nor the names of its contributors 
;;;       may be used to endorse or promote products derived from this software 
;;;       without specific prior written permission.
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

(in-package :pr2-manip-pm)

(defvar *left-feature-constraints-config-pub* nil)
(defvar *left-feature-constraints-command-pub* nil)
(defvar *left-feature-controller-state-subscriber* nil)
(defvar *right-feature-constraints-config-pub* nil)
(defvar *right-feature-constraints-command-pub* nil)
(defvar *right-feature-controller-state-subscriber* nil)

(defvar *left-feature-controller-state-active-fluent* nil)
(defvar *right-feature-controller-state-active-fluent* nil)

(defvar *tf-broadcaster* nil)

(defun init-feature-constraints-controller ()
  (setf *left-feature-constraints-command-pub*
        (roslisp:advertise
         "/left_arm_feature_controller/constraint_command"
         "constraint_msgs/ConstraintCommand"))
  (setf *left-feature-constraints-config-pub*
        (roslisp:advertise
         "/left_arm_feature_controller/constraint_config"
         "constraint_msgs/ConstraintConfig"
         :latch t))
  (setf *left-feature-controller-state-active-fluent*
        (cram-language:make-fluent :name :left-feature-controller-state-fluent
                                   :allow-tracing nil))
  (setf *left-feature-controller-state-subscriber*
        (roslisp:subscribe
         "/left_arm_feature_controller/constraint_state"
         "constraint_msgs/ConstraintState"
         #'left-feature-constraints-controller-state-callback))
  (setf *right-feature-constraints-command-pub*
        (roslisp:advertise
         "/right_arm_feature_controller/constraint_command"
         "constraint_msgs/ConstraintCommand"))
  (setf *right-feature-constraints-config-pub*
        (roslisp:advertise
         "/right_arm_feature_controller/constraint_config"
         "constraint_msgs/ConstraintConfig"
         :latch t))
  (setf *right-feature-controller-state-active-fluent*
        (cram-language:make-fluent :name :right-feature-controller-state-fluent
                                   :allow-tracing nil))
  (setf *right-feature-controller-state-subscriber*
        (roslisp:subscribe
         "/right_arm_feature_controller/constraint_state"
         "constraint_msgs/ConstraintState"
         #'right-feature-constraints-controller-state-callback))
  (setf *tf-broadcaster*
        (cl-tf:make-transform-broadcaster)))

(register-ros-init-function init-feature-constraints-controller)

(defun left-feature-constraints-controller-state-callback (msg)
  "Checks whether all weight entries in 'msg' are smaller than 1.0. If yes a pulse on the fluent for the feature constraints controller of the left arm is sent."
  ;(declare (type 'constraint_msgs-msg:<ConstraintState> msg))
  (roslisp:with-fields (weights) msg
    (let ((max-weight (loop for i from 0 below (length weights)
                            for weight = (elt weights i)
                            maximizing weight into max-weight
                            finally (return max-weight))))
      (cond ((< max-weight 1.0)
             ;; All weights are < 1.0, meaning that all constraints are
             ;; satisfied.
             (setf (cram-language:value *left-feature-controller-state-active-fluent*) T)
             (cram-language:pulse *left-feature-controller-state-active-fluent*))
            (t (setf (cram-language:value
                      *left-feature-controller-state-active-fluent*) nil))))))

(defun right-feature-constraints-controller-state-callback (msg)
  "Checks whether all weight entries in 'msg' are smaller than 1.0. If yes a pulse on the fluent for the feature constraints controller of the right arm is sent."
  ;(declare (type 'constraint_msgs-msg:<ConstraintState> msg))
  (roslisp:with-fields (weights) msg
    (let ((max-weight (loop for i from 0 below (length weights)
                            for weight = (elt weights i)
                            maximizing weight into max-weight
                            finally (return max-weight))))
      (cond ((< max-weight 1.0)
             ;; All weights are < 1.0, meaning that all constraints are
             ;; satisfied.
             (setf (cram-language:value *right-feature-controller-state-active-fluent*) T)
             (cram-language:pulse *right-feature-controller-state-active-fluent*))
            (t (setf (cram-language:value
                      *right-feature-controller-state-active-fluent*) nil))))))

(defun wait-for-feature-controller (side &optional (timeout nil))
  "Waits 'timeout' seconds for the fluent watching the feature constraints controller of arm 'side' to become true. Returns nil if a timeout occured, otherwise returns something non-nil."
  (let ((fluent (ecase side
                  (:left *left-feature-controller-state-active-fluent*)
                  (:right *right-feature-controller-state-active-fluent*))))
    (cram-language:wait-for fluent :timeout timeout)))

(defun send-constraints-config (constraints side)
  "Takes a list of constraints 'constraints' and sends the resulting configuration-msg to the feature constraints controller of arm 'side' to prepare it for a subsequent command."
  (let ((publisher (ecase side
                     (:left *left-feature-constraints-config-pub*)
                     (:right *right-feature-constraints-config-pub*))))
    (roslisp:publish
     publisher
     (cram-feature-constraints:feature-constraints->config-msg constraints))))

(defun send-constraints-command (constraints side)
  "Takes a list of constraints 'constraints' and sends the resulting command-msg to the feature constraints controller of arm 'side' to start the controller."
  (let ((publisher (ecase side
                     (:left *left-feature-constraints-command-pub*)
                     (:right *right-feature-constraints-command-pub*))))
    (roslisp:publish
     publisher
     (cram-feature-constraints:feature-constraints->command-msg constraints))))

(defun start-velocity-resolved-controllers (side)
  (declare (ignore side)))

(defun shutdown-velocity-resolved-controllers (side)
  (declare (ignore side)))

(defun turn-down-feature-controllers (thread-list)
  (declare (ignore thread-list)))

(defun grasp-ketchup-bottle ()
  (let* ((object-stamped-transform
           (cl-tf:make-stamped-transform "/base_link"
                                         "/ketchup_frame"
                                         (roslisp:ros-time)
                                         (cl-transforms:make-3d-vector 0.6 0.0 0.8)
                                         (cl-transforms:make-identity-rotation)))
         ;; start threads to broadcaster tool and object transforms
         (tf-object-thread
           (cl-tf:send-static-transform *tf-broadcaster*
                                        object-stamped-transform
                                        :interval 0.02))
         ;; model the features on the objects
         (ketchup-main-axis
           (make-instance
            'cram-feature-constraints:geometric-feature
            :name "main axis ketchup bottle"
            :frame-id "/ketchup_frame"
            :feature-type 'cram-feature-constraints:line
            :feature-position (cl-transforms:make-3d-vector 0.0 0.0 0.0)
            :feature-direction (cl-transforms:make-3d-vector 0.0 0.0 0.1)
            :contact-direction (cl-transforms:make-3d-vector 0.1 0.0 0.0)))
         ;; using pointing-3d removes the need for this 'virtual feature'
         (ketchup-plane
           (make-instance
            'cram-feature-constraints:geometric-feature
            :name "plane through ketchup bottle"
            :frame-id "/ketchup_frame"
            :feature-type 'cram-feature-constraints:plane
            :feature-position (cl-transforms:make-3d-vector 0.0 0.0 0.0)
            :feature-direction (cl-transforms:make-3d-vector 0.0 0.0 0.1)
            :contact-direction (cl-transforms:make-3d-vector 0.1 0.0 0.0)))
         (ketchup-left-right-plane
           (make-instance
            'cram-feature-constraints:geometric-feature
            :name "left-right-plane"
            :frame-id "/ketchup_frame"
            :feature-type 'cram-feature-constraints:plane
            :feature-position (cl-transforms:make-3d-vector 0.0 0.0 0.0)
            :feature-direction (cl-transforms:make-3d-vector 0.0 0.1 0.0)
            :contact-direction (cl-transforms:make-3d-vector 0.1 0.0 0.0)))
         (gripper-plane
           (make-instance
            'cram-feature-constraints:geometric-feature
            :name "left gripper plane"
            :frame-id "/l_gripper_tool_frame"
            :feature-type 'cram-feature-constraints:plane
            :feature-position (cl-transforms:make-3d-vector 0.0 0.0 0.0)
            :feature-direction (cl-transforms:make-3d-vector 0.0 0.0 0.1)
            :contact-direction (cl-transforms:make-3d-vector 0.1 0.0 0.0)))
         (gripper-main-axis
           (make-instance
            'cram-feature-constraints:geometric-feature
            :name "left gripper main axis"
            :frame-id "/l_gripper_tool_frame"
            :feature-type 'cram-feature-constraints:line
            :feature-position (cl-transforms:make-3d-vector 0.0 0.0 0.0)
            :feature-direction (cl-transforms:make-3d-vector 0.1 0.0 0.0)
            :contact-direction (cl-transforms:make-3d-vector 0.0 0.1 0.0)))
         ; now model the constraints
         (gripper-vertical-constraint
           (make-instance
            'cram-feature-constraints:feature-constraint
            :name "gripper vertical constraint"
            :feature-function "perpendicular"
            :tool-feature gripper-plane
            :world-feature ketchup-main-axis
            :lower-boundary 0.95
            :upper-boundary 1.5
            :weight 1.0
            :maximum-velocity 0.2
            :minimum-velocity -0.2))
         (gripper-pointing-at-ketchup
           (make-instance
            'cram-feature-constraints:feature-constraint
            :name "gripper pointing at ketchup"
            :feature-function "pointing_at"
            :tool-feature gripper-main-axis
            :world-feature ketchup-plane
            :lower-boundary -0.05
            :upper-boundary 0.05
            :weight 1.0
            :maximum-velocity 0.2
            :minimum-velocity -0.2))
         (gripper-height-constraint
           (make-instance
            'cram-feature-constraints:feature-constraint
            :name "gripper height constraint"
            :feature-function "height"
            :tool-feature gripper-plane
            :world-feature ketchup-plane
            :lower-boundary -0.05
            :upper-boundary 0.05
            :weight 1.0
            :maximum-velocity 0.1
            :minimum-velocity -0.1))
         (gripper-distance-constraint
          (make-instance
            'cram-feature-constraints:feature-constraint
            :name "gripper distance constraint"
            :feature-function "distance"
            :tool-feature gripper-plane
            :world-feature ketchup-plane
            :lower-boundary 0.1
            :upper-boundary 0.2
            :weight 1.0
            :maximum-velocity 0.1
            :minimum-velocity -0.1))
         (gripper-left-of-constraint
          (make-instance
            'cram-feature-constraints:feature-constraint
            :name "gripper left constraint"
            :feature-function "height"
            :tool-feature gripper-plane
            :world-feature ketchup-left-right-plane
            :lower-boundary 0.02
            :upper-boundary 2.00
            :weight 1.0
            :maximum-velocity 0.1
            :minimum-velocity -0.1)))
    (let ((constraint-list (list
                            gripper-vertical-constraint
                            gripper-pointing-at-ketchup
                            gripper-height-constraint
                            gripper-distance-constraint
                            gripper-left-of-constraint)))
      (send-constraints-config constraint-list)
      (sleep 0.5)
      (send-constraints-command constraint-list)
      (switch-controller (list "l_arm_vel") (list "l_arm_controller"))
      (wait-for-controller)
      (switch-controller (list "l_arm_controller") (list "l_arm_vel"))
      (sb-thread:terminate-thread tf-object-thread))))