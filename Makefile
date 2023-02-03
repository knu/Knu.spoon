VERSION=	$(shell git describe --tags --abbrev=0 2>/dev/null)
NAME=		Knu
SPOON=		$(NAME).spoon
RELEASE=	$(SPOON).zip

release:
	@git archive --format=zip --prefix=$(SPOON)/ @ > $(RELEASE)
	@git switch release
	@mv $(RELEASE) Spoons/
	@git add Spoons
	@git commit -m "$(VERSION)"
	@git push -f
	@git switch -
