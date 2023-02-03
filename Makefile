VERSION=	$(shell git describe --tags --abbrev=0 2>/dev/null)
NAME=		Knu
SPOON=		$(NAME).spoon
RELEASE=	$(SPOON).zip

all:
	@echo no default target

bump:
	@git tag "$$(sh -c 'echo $${1%.*}.$$(($${1##*.}+1))' . $(VERSION))"

release:
	@git push --tags
	@git archive --format=zip --prefix=$(SPOON)/ @ > $(RELEASE)
	@gh release create $(VERSION) --generate-notes
	@gh release upload $(VERSION) $(RELEASE)
	@git switch release
	@mv $(RELEASE) Spoons/
	@git add Spoons
	@git commit -m "$(VERSION)"
	@git push -f
	@git switch -
