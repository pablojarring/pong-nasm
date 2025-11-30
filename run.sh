#!/bin/bash
echo "Construyendo la imagen..."
docker build -t pong-asm .

echo "Iniciando el juego..."
# Quitamos --rm para que el contenedor persista
docker run -it pong-asm