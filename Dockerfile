FROM alpine:latest

ENV PHANTOMJS_VERSION 2.1.1
COPY *.patch /

RUN apk add --no-cache --virtual .build-deps \
		bison \
		flex \
		fontconfig-dev \
		freetype-dev \
		g++ \
		gcc \
		git \
		gperf \
		icu-dev \
		libc-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libx11-dev \
		libxext-dev \
		linux-headers \
		make \
		openssl-dev \
		paxctl \
		perl \
		python \
		ruby \
		sqlite-dev \
	&& mkdir -p /usr/src \
	&& cd /usr/src \
	&& git clone git://github.com/ariya/phantomjs.git \
	&& cd phantomjs \
	&& git checkout $PHANTOMJS_VERSION \
	&& git submodule init \
	&& git submodule update \
	&& for i in qtbase qtwebkit; do \
		cd /usr/src/phantomjs/src/qt/$i \
			&& patch -p1 -i /$i*.patch || break; \
		done \
	&& cd /usr/src/phantomjs \
	&& patch -p1 -i /build.patch

# build phantomjs
RUN cd /usr/src/phantomjs \
  && python build.py --confirm \
	&& paxctl -cm bin/phantomjs \
	&& strip --strip-all bin/phantomjs \
	&& install -m755 bin/phantomjs /usr/bin/phantomjs \
	&& runDeps="$( \
		scanelf --needed --nobanner /usr/bin/phantomjs \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --virtual .phantomjs-rundeps $runDeps \
	&& apk del .build-deps \
	&& rm -r /*.patch /usr/src

RUN apk add patchelf --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/community/ --allow-untrusted

# package binary build
RUN cd /root \
  && mkdir -p phantomjs/lib \
  && cp /usr/bin/phantomjs phantomjs/ \
  && cd phantomjs \
    && for lib in `ldd phantomjs \
      | awk '{if(substr($3,0,1)=="/") print $1,$3}' \
      | cut -d' ' -f2`; do \
        cp $lib lib/`basename $lib`; \
      done \
    && patchelf --set-rpath '$ORIGIN/lib' phantomjs \
  && cd /root \
  && tar cvf phantomjs.tar phantomjs \
  && bzip2 -9 phantomjs.tar

