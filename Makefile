VERSION=	$(shell git describe --tags 2>/dev/null || echo v1.0.0-pre)
NAME=		Knu
SPOON=		$(NAME).spoon
PACKAGE=	Hammerspoon-$(NAME)-$(VERSION).zip

archive:
	@git archive --format=zip --prefix=$(SPOON)/ @ > $(PACKAGE)
	@ls -l $(PACKAGE)
