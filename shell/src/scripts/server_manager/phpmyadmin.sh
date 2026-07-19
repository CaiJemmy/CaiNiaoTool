#!/bin/bash

install_phpMyAdmin() {
    if [ -e "${php_install_dir}/bin/phpize" ]; then
        if [[ -d ${wwwroot_dir}/default/phpMyAdmin/ ]]; then
            log_info "phpMyAdmin already installed!"
            return 0
        fi

        pushd ${CAINIAOTOOL_ROOT}/src >/dev/null

        tar xzf phpMyAdmin-${phpmyadmin_ver}-all-languages.tar.gz
        /bin/mv phpMyAdmin-${phpmyadmin_ver}-all-languages ${wwwroot_dir}/default/phpMyAdmin
        /bin/cp ${wwwroot_dir}/default/phpMyAdmin/{config.sample.inc.php,config.inc.php}
        mkdir ${wwwroot_dir}/default/phpMyAdmin/{upload,save}

        sed -i "s@UploadDir.*@UploadDir'\] = 'upload';@" ${wwwroot_dir}/default/phpMyAdmin/config.inc.php
        sed -i "s@SaveDir.*@SaveDir'\] = 'save';@" ${wwwroot_dir}/default/phpMyAdmin/config.inc.php
        sed -i "s@host'\].*@host'\] = '127.0.0.1';@" ${wwwroot_dir}/default/phpMyAdmin/config.inc.php
        sed -i "s@blowfish_secret.*;@blowfish_secret\'\] = \'${phpMyAdminpwd}\';@" ${wwwroot_dir}/default/phpMyAdmin/config.inc.php
        chown -R ${run_user}:${run_group} ${wwwroot_dir}/default/phpMyAdmin

        log_info "phpMyAdmin installed successfully!"

        popd >/dev/null
    fi
}
