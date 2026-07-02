# GeoCampo App

Frontend Flutter para GeoCampo.

## Ejecutar

La app solo requiere saber donde esta el backend mediante `API_BASE_URL`.

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8001
```

El cliente agrega automaticamente el prefijo `/api`, asi que `API_BASE_URL` debe ser solo el origen del backend:

```text
http://localhost:8001
https://tu-dominio.com
```

## URLs utiles por plataforma

```bash
# Chrome / Windows, backend en la misma maquina
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8001

# Android Emulator, backend en la maquina host
flutter run -d emulator --dart-define=API_BASE_URL=http://10.0.2.2:8001

# Celular fisico, backend en tu red local
flutter run --dart-define=API_BASE_URL=http://IP_LOCAL_DE_TU_PC:8001
```

## Builds

Para produccion, compila apuntando al dominio real del backend:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://tu-dominio.com
flutter build windows --release --dart-define=API_BASE_URL=https://tu-dominio.com
```
