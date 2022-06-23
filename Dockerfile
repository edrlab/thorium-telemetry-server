
FROM openresty/openresty:alpine-fat

RUN opm get jkeys089/lua-resty-hmac

RUN opm get openresty/lua-resty-mysql

RUN opm list

COPY conf.d /etc/nginx/conf.d

COPY lua /lua

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 80
