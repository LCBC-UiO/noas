convert logo_noshadow.png -define icon:auto-resize=64,48,32,16 favicon.ico
convert logo_noshadow.png -define icon:auto-resize=64,48,32,16 -unsharp 2x1.0+0.9+0 ../webui/static/img/favicon.ico
