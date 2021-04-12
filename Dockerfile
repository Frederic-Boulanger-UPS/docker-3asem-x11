FROM ubuntu:20.04

# For which architecture to build (amd64 or arm64)
ARG arch

# Avoid prompts for time zone
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Paris

# Fix issue with libGL on Windows
ENV LIBGL_ALWAYS_INDIRECT=1

# Update and upgrade apt software
RUN apt-get update && apt-get upgrade -y

# Install some necessary stuff to get and build programs
RUN apt-get install -y x11-apps xdg-utils wget make cmake nano python3-pip

# Install ocaml stuff for why3
RUN apt-get install -y ocaml menhir \
  libnum-ocaml-dev libzarith-ocaml-dev libzip-ocaml-dev \
  libmenhir-ocaml-dev liblablgtk3-ocaml-dev liblablgtksourceview3-ocaml-dev \
  libocamlgraph-ocaml-dev libre-ocaml-dev libjs-of-ocaml-dev

# Install Coq and Alt-ergo for Why3
RUN apt-get install -y coqide alt-ergo

# Install Z3 4.8.6
RUN wget https://github.com/Z3Prover/z3/archive/z3-4.8.6.tar.gz \
	&& tar zxf z3-4.8.6.tar.gz \
	&& cd z3-z3-4.8.6; env PYTHON=python3 ./configure; cd build; make; make install; \
	cd ../..; rm -r z3-*

# Install E prover
RUN wget http://wwwlehre.dhbw-stuttgart.de/~sschulz/WORK/E_DOWNLOAD/V_2.0/E.tgz \
	 && tar zxf E.tgz \
	 && cd E; ./configure --prefix=/usr/local; make; make install; \
	 cd ..; rm -r E E.tgz

# Install Isabelle 2021
ARG ISATARGZ=Isabelle2021_linux.tar.gz
ARG ISAINSTDIR=Isabelle2021
ARG ISABIN=isabelle2021
ARG ISADESKTOP=resources/Isabelle2021/Isabelle.desktop
# ARG ISAPREFS=resources/dot_isabelle_2021
ARG ISAJDK=/usr/local/Isabelle2021/contrib/jdk-15.0.2+7/x86_64-linux
ARG ISAHEAPSDIR=Isabelle2021/heaps/polyml-5.8.2_x86_64_32-linux

RUN wget https://isabelle.in.tum.de/dist/${ISATARGZ} \
  && tar -xzf ${ISATARGZ} \
  && mv ${ISAINSTDIR} /usr/local/ \
  && ln -s /usr/local/${ISAINSTDIR}/bin/isabelle /usr/local/bin/${ISABIN} \
  && ln -s /usr/local/bin/${ISABIN} /usr/local/bin/isabelle

# Reuse the SMT solvers embedded into the Isabelle distribution
RUN ln -s /usr/local/${ISAINSTDIR}/contrib/spass-3.8ds-2/x86_64-linux/SPASS /usr/local/bin/SPASS
RUN ln -s /usr/local/${ISAINSTDIR}/contrib/vampire-4.2.2/x86_64-linux/vampire /usr/local/bin/vampire
# These ones will be built using the version supported by why3
# RUN ln -s /usr/local/${ISAINSTDIR}/contrib/cvc4-1.8/x86_64-linux/cvc4 /usr/local/bin/cvc4
# RUN ln -s /usr/local/${ISAINSTDIR}/contrib/e-2.5-1/x86_64-linux/eprover /usr/local/bin/eprover
# RUN ln -s /usr/local/${ISAINSTDIR}/contrib/z3-4.4.0pre-3/x86_64-linux/z3 /usr/local/bin/z3

# Get rid of the distribution archive
RUN rm ${ISATARGZ}

COPY ${ISADESKTOP} /usr/share/applications/
COPY resources/dot_isabelle_2021.tar /
RUN cd /root; mkdir .isabelle ; cd .isabelle; tar xvf /dot_isabelle_2021.tar; rm /dot_isabelle_2021.tar
# RUN echo 'cp -r /root/.isabelle ${HOME}' >> /root/.novnc_setup

# Reuse the JDK provided with Isabelle for the whole system
RUN ln -s ${ISAJDK}/bin/java /usr/local/bin/ ; \
    ln -s ${ISAJDK}/bin/javac /usr/local/bin/

# Install CVC4, only on amd64/x86_64 (fails on arm64)
# CVC4 requires Java (for ANTLR)
RUN if [ "$arch" = "amd64" ]; then pip3 install toml; fi
# Reuse JDK from Isabelle
# RUN if [ "$arch" = "amd64" ]; then apt-get install -y openjdk-14-jdk; fi
RUN if [ "$arch" = "amd64" ]; then \
			wget https://github.com/CVC4/CVC4/archive/1.7.tar.gz \
	    && tar zxf 1.7.tar.gz ; \
	  fi
RUN if [ "$arch" = "amd64" ]; then \
	    cd CVC4-1.7; ./contrib/get-antlr-3.4 && ./configure.sh \
	    && cd build && make && make install; \
	  fi
RUN if [ "$arch" = "amd64" ]; then rm -r CVC4* && rm 1.7.tar.gz; fi

RUN apt autoremove && apt autoclean

# Install Why3 when working with Isabelle 2021
COPY resources/why3.tar /
RUN wget https://gforge.inria.fr/frs/download.php/file/38291/why3-1.3.1.tar.gz
RUN tar zxf why3-1.3.1.tar.gz
RUN cd why3-1.3.1 && tar xvf /why3.tar ; rm /why3.tar
RUN cd why3-1.3.1 && ./configure && make \
    && echo "/usr/local/lib/why3/isabelle" >> /usr/local/${ISAINSTDIR}/etc/components
RUN cd why3-1.3.1/lib/isabelle; cp ROOT.2021 ROOT 
RUN cd why3-1.3.1; make install; make byte; make install-lib
RUN mv ${HOME}/.isabelle/${ISAHEAPSDIR}/Why3 /usr/local/${ISAHEAPSDIR}/ ;\
    mv ${HOME}/.isabelle/${ISAHEAPSDIR}/log/* /usr/local/${ISAHEAPSDIR}/log/
RUN rm -r why3-1.3.1 why3-1.3.1.tar.gz

# Configure Why3 with SMT provers and save the configuration file
RUN why3 config --detect-provers
# RUN echo 'cp /root/.why3.conf ${HOME}' >> /root/.novnc_setup

# Install Eclipse Modeling 2020-06
# Copy existing configuration containing:
# * Eclipse Modeling 2020-06
# * Acceleo 3.7 from the OBEO Market Place
# * From Install New Software (with all available sites)
#   * All Acceleo
#   * Additional Interpreters for Acceleo
#   * Modeling > all QVT operational
#   * Modeling > Xpand SDK
#   * Modeling > Xtext SDK
#   * Programming languages > C/C++ Dev Tools
#   * Programming languages > C/C++ library API doc hover help
#   * Programming languages > C/C++ Unit Testing
#   * Programming languages > Eclipse XML editors and tools
#   * Programming languages > Javascript dev tools
#   * Programming languages > Wild Web developer
# * My MicroC feature from https://wdi.centralesupelec.fr/boulanger/misc/microc-update-site/
ARG ECLIPSETGZ=eclipse-modeling-2020-06-microc.tgz
ARG ECLIPSEINSTDIR=/usr/local/eclipse-modeling-2020-06
COPY resources/${ECLIPSETGZ} /usr/local/
RUN cd /usr/local; tar zxf ${ECLIPSETGZ} \
    && rm ${ECLIPSETGZ}; \
    ln -s ${ECLIPSEINSTDIR}/eclipse /usr/local/bin/eclipse
COPY resources/Eclipse.desktop /usr/share/applications/
COPY resources/dot_eclipse /root/.eclipse
# RUN echo 'cp -r /root/.eclipse ${HOME}' >> /root/.novnc_setup

# RUN useradd --create-home --skel /root --shell /bin/bash --user-group ubuntu \
#     && echo "ubuntu:ubuntu" | chpasswd

RUN apt-get install dbus-x11

RUN rm -rf /tmp/*

COPY resources/startup.sh /
ENTRYPOINT /startup.sh
