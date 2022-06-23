
FROM openresty/openresty:alpine-fat

RUN opm get jkeys089/lua-resty-hmac

RUN opm get openresty/lua-resty-mysql

RUN opm list

COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY conf.d/nginx.conf /etc/nginx/conf.d/nginx.conf

COPY lua /lua

RUN rm -f /etc/nginx/conf.d/default.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 80
