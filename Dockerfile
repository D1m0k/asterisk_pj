FROM ghcr.io/d1m0k/callbot_centos/system:main
WORKDIR /usr/src 
RUN git clone -b certified/18.9-cert1 --depth 1 https://github.com/asterisk/asterisk.git asterisk 
WORKDIR /usr/src/asterisk
# Configure
RUN ls -l
RUN sh contrib/scripts/install_prereq install
RUN sh contrib/scripts/get_mp3_source.sh 
RUN ./configure 1> /dev/null 
RUN make -j$(nproc) menuselect.makeopts
RUN menuselect/menuselect \
  --disable BUILD_NATIVE \
  --enable format_mp3 \
  --enable cdr_csv \
  --enable chan_sip \
  --enable res_snmp \
  --enable res_http_websocket \
  --enable res_hep_pjsip \
  --enable res_hep_rtcp \
  --enable res_sorcery_astdb \
  --enable res_sorcery_config \
  --enable res_sorcery_memory \
  --enable res_sorcery_memory_cache \
  --enable res_pjproject \
  --enable res_rtp_asterisk \
  --enable res_ari \
  --enable res_ari_applications \
  --enable res_ari_asterisk \
  --enable res_ari_bridges \
  --enable res_ari_channels \
  --enable res_ari_device_states \
  --enable res_ari_endpoints \
  --enable res_ari_events \
  --enable res_ari_mailboxes \
  --enable res_ari_model \
  --enable res_ari_playbacks \
  --enable res_ari_recordings \
  --enable res_ari_sounds \
  --enable res_pjsip \
  --enable res_pjsip_acl \
  --enable res_pjsip_authenticator_digest \
  --enable res_pjsip_caller_id \
  --enable res_pjsip_config_wizard \
  --enable res_pjsip_dialog_info_body_generator \
  --enable res_pjsip_diversion \
  --enable res_pjsip_dlg_options \
  --enable res_pjsip_dtmf_info \
  --enable res_pjsip_empty_info \
  --enable res_pjsip_endpoint_identifier_anonymous \
  --enable res_pjsip_endpoint_identifier_ip \
  --enable res_pjsip_endpoint_identifier_user \
  --enable res_pjsip_exten_state \
  --enable res_pjsip_header_funcs \
  --enable res_pjsip_logger \
  --enable res_pjsip_messaging \
  --enable res_pjsip_mwi \
  --enable res_pjsip_mwi_body_generator \
  --enable res_pjsip_nat \
  --enable res_pjsip_notify \
  --enable res_pjsip_one_touch_record_info \
  --enable res_pjsip_outbound_authenticator_digest \
  --enable res_pjsip_outbound_publish \
  --enable res_pjsip_outbound_registration \
  --enable res_pjsip_path \
  --enable res_pjsip_pidf_body_generator \
  --enable res_pjsip_publish_asterisk \
  --enable res_pjsip_pubsub \
  --enable res_pjsip_refer \
  --enable res_pjsip_registrar \
  --enable res_pjsip_rfc3326 \
  --enable res_pjsip_sdp_rtp \
  --enable res_pjsip_send_to_voicemail \
  --enable res_pjsip_session \
  --enable res_pjsip_sips_contact \
  --enable res_pjsip_t38 \
  --enable res_pjsip_transport_websocket \
  --enable res_pjsip_xpidf_body_generator \
  --enable res_stasis \
  --enable res_stasis_answer \
  --enable res_stasis_device_state \
  --enable res_stasis_mailbox \
  --enable res_stasis_playback \
  --enable res_stasis_recording \
  --enable res_stasis_snoop \
  --enable res_stasis_test \
  --enable res_statsd \
  --enable res_timing_timerfd \
  --enable pbx_ael \
  menuselect.makeopts \
  && make -j$(nproc) 1> /dev/null \
  && make -j$(nproc) install 1> /dev/null \
  && make -j$(nproc) samples 1> /dev/null
WORKDIR /usr/src 
RUN git clone https://github.com/alphacep/vosk-asterisk.git 
WORKDIR /usr/src/vosk-asterisk 
RUN mkdir /etc/asterisk/sip /etc/asterisk/dialplan /etc/asterisk/ael 
RUN ./bootstrap \
    && ./configure --with-asterisk=/usr/src/asterisk --prefix=/usr \
    && make \
    && make install \
    && cp -R /usr/etc/asterisk/ /etc/ \
    && sed -i -e 's/noload = chan_sip.so/require = chan_sip.so/' /etc/asterisk/modules.conf \
    && echo 'load = res_speech_vosk.so' >> /etc/asterisk/modules.conf \
    && echo '#tryinclude "sip/*.conf"' >> /etc/asterisk/sip.conf \
    && echo '#tryinclude "dialplan/*.conf"' >> /etc/asterisk/extensions.conf \
    && echo '#include "ael/*.conf"' >> /etc/asterisk/extensions.ael \
    && echo 'HISTFILE=$HOME/.bash_history' >> /etc/skel/.bashrc \
    && echo 'LANG="ru_RU.UTF-8"' > /etc/locale.conf \
    && echo 'LC_ALL="ru_RU.UTF-8"' >> /etc/locale.conf \
    && echo $'set tabsize 4\nset tabstospaces\ninclude /usr/share/nano/*' >> /etc/skel/.nanorc \
    && echo $'[general]\nurl = ws://127.0.0.1:2700' > /etc/asterisk/res_speech_vosk.conf \
    # Update max number of open files.
    && sed -i -e 's/# MAXFILES=/MAXFILES=/' /usr/sbin/safe_asterisk \
    # Set tty
    && sed -i 's/TTY=9/TTY=/g' /usr/sbin/safe_asterisk \
    # Create and configure asterisk for running asterisk user.
    && useradd -m asterisk -s /sbin/nologin \
    && chown -R asterisk:asterisk /var/run/asterisk \
                                  /etc/asterisk/ \
                                  /var/lib/asterisk \
                                  /var/log/asterisk \
                                  /var/spool/asterisk
# Running asterisk with user asterisk.
VOLUME /var/lib/asterisk/agi-bin /etc/asterisk/ael /etc/asterisk/sip /etc/asterisk/dialplan/ /var/lib/asterisk/sounds
EXPOSE 5060/UDP
EXPOSE 5060/TCP
EXPOSE 10000-20000/UDP
USER root
CMD /usr/sbin/asterisk -fvvvvv