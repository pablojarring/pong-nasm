# Usamos una imagen base ligera de Ubuntu
FROM --platform=linux/amd64 ubuntu:latest

# Evitar preguntas interactivas durante la instalación
ENV DEBIAN_FRONTEND=noninteractive

# Instalar NASM, herramientas de compilación y utilidades básicas
RUN apt-get update && apt-get install -y \
    nasm \
    build-essential \
    binutils \
    && rm -rf /var/lib/apt/lists/*

# Establecer el directorio de trabajo dentro del contenedor
WORKDIR /app

# Copiar el código fuente al contenedor
COPY juego.asm .

# Compilar el juego (instrucciones que ya usabas)
RUN nasm -f elf32 juego.asm -o juego.o && \
    ld -m elf_i386 juego.o -o juego

# Comando por defecto al iniciar el contenedor
CMD ["./juego"]
