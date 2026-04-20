;;; build.el --- Export all org/ files to HTML in html/
;;
;; Usage:
;;   emacs --batch --load build.el
;;
;; Exports every .org file in org/ to html/.
;; Static assets (css, js, images) in static/ are copied to html/static/.

(require 'ox-publish)

;; Resolve all paths relative to this file so the script works from any
;; working directory.
(defvar build-root
  (file-name-directory (or load-file-name buffer-file-name))
  "Absolute path to the project root (where build.el lives).")

;; Derive a project name from the directory name so this script is
;; reusable in any directory (e.g. "music", "recipes", "notes").
(defvar build-project-name
  (file-name-base (directory-file-name build-root))
  "Short name used to label ox-publish components.")

;; Delete html/ output so every build starts completely fresh.
(let ((html-dir (expand-file-name "html" build-root)))
  (when (file-directory-p html-dir)
    (delete-directory html-dir t))
  (make-directory html-dir t))

(setq org-publish-project-alist
      `((,(concat build-project-name "-notes")
         :base-directory      ,(expand-file-name "org"    build-root)
         :base-extension      "org"
         :publishing-directory ,(expand-file-name "html"  build-root)
         :publishing-function  org-html-publish-to-html
         :recursive            nil

         ;; HTML output
         :html-doctype         "html5"
         :html-html5-fancy     t
         :with-toc             t
         :section-numbers      nil
         :with-author          nil
         :with-timestamps      nil
         :html-postamble       nil

         ;; Link the project stylesheet.
         :html-head-extra      "<link rel=\"stylesheet\" href=\"static/style.css\">")

        (,(concat build-project-name "-static")
         :base-directory       ,(expand-file-name "static" build-root)
         :base-extension       "css\\|js\\|png\\|jpg\\|svg\\|ico\\|woff2\\|woff"
         :publishing-directory ,(expand-file-name "html/static" build-root)
         :publishing-function  org-publish-attachment
         :recursive            t)

        (,build-project-name
         :components (,(concat build-project-name "-notes")
                      ,(concat build-project-name "-static")))))

;; Force full re-export on every run (ignore the publish cache).
(org-publish build-project-name t)

(message "\nBuild complete → %s" (expand-file-name "html" build-root))

;; Start simple-httpd server serving html/ and open browser.
(let* ((html-dir (expand-file-name "html" build-root))
       (port 8080))
  (if (not noninteractive)
      ;; Interactive Emacs: start the server in this process.
      (progn
        (require 'simple-httpd)
        (setq httpd-root html-dir
              httpd-port port)
        (httpd-start)
        (message "simple-httpd serving %s on http://localhost:%d" html-dir port))
    ;; Batch mode: spawn a background Emacs process to run the server.
    (let ((eval-str
           (format (concat "(progn"
                           " (package-initialize)"
                           " (require 'simple-httpd)"
                           " (setq httpd-root \"%s\" httpd-port %d)"
                           " (httpd-start)"
                           " (message \"httpd serving %%s on port %%d\" httpd-root httpd-port)"
                           " (while t (sleep-for 3600)))")
                   html-dir port)))
      (call-process "emacs" nil 0 nil "--batch" "--eval" eval-str)))
  ;; Open browser pointing at the local server.
  (call-process "xdg-open" nil 0 nil
                (format "http://localhost:%d/" port)))
