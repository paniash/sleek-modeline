# justfile

pkg     := "sleek-modeline"
emacs   := env_var_or_default("EMACS", "emacs")
files   := "sleek-modeline-core.el sleek-modeline-vc.el sleek-modeline-diagnostics.el sleek-modeline-lsp.el sleek-modeline-project.el sleek-modeline.el"
batch   := emacs + " -Q --batch -L ."

# Cache for lint dependencies
lint_dir := justfile_directory() + "/.elpa-lint"

@_default:
    just --list

# Build everything
build: compile autoloads

# Byte-compile all .el files
compile:
    @{{batch}} --eval "(setq byte-compile-error-on-warn t)" \
        -f batch-byte-compile {{files}}

# Generate autoloads file
autoloads:
    @{{batch}} --eval "(require 'loaddefs-gen)" \
        --eval "(loaddefs-generate default-directory \
                  (expand-file-name \"{{pkg}}-autoloads.el\"))"

# Verify declare-function correctness
check:
    @{{batch}} --eval "(check-declare-directory default-directory)"

# Lint the main package file
lint:
    @{{batch}} \
        --eval "(setq package-user-dir \"{{lint_dir}}\")" \
        --eval "(require 'package)" \
        --eval "(add-to-list 'package-archives '(\"melpa\" . \"https://melpa.org/packages/\") t)" \
        --eval "(package-initialize)" \
        --eval "(unless (package-installed-p 'package-lint) \
                  (package-refresh-contents) \
                  (package-install 'package-lint))" \
        --eval "(require 'package-lint)" \
        -f package-lint-batch-and-exit {{pkg}}.el
	
# Wipe build artifacts & lint dependency cache
clean:
    @rm -f *.elc {{pkg}}-autoloads.el
    @rm -rf {{lint_dir}}
