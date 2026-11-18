# Hora do Rush

Jogo de plataforma 2D de motoqueiro entregador — Trabalho A3.

Colete pedidos nos restaurantes, entregue no portão do cliente dentro do prazo, digite o código "quebradiço" e não deixe a gasolina acabar. Errar custa pontos; **gasolina zerada é game over**.

O design completo está em [`docs/GDD.md`](docs/GDD.md).

## Como rodar

1. Instale o **Godot 4.7** (versão padrão, não a .NET): <https://godotengine.org/download>
   - No Windows também dá pelo terminal: `winget install GodotEngine.GodotEngine`
2. Abra o Godot → **Importar** → selecione o arquivo `project.godot` desta pasta.
3. Aperte **F5** (ou o botão ▶) para jogar.

## Controles

| Ação | PC | Celular |
|---|---|---|
| Pilotar | `A` / `D` ou setas | botões `<` `>` |
| Freio | `S`, `↓` ou `Shift` | botão FREIO |
| Pulo | `Espaço`, `W` ou `↑` | botão PULO |
| Equilibrar no ar (após lombada / boca de lobo) | `A` / `D` | botões `<` `>` |
| Código no portão | teclas numéricas | teclado na tela |

Os botões de toque aparecem automaticamente em telas sensíveis ao toque. Para vê-los no PC, rode com o argumento `-- --toque`.

## Estrutura

```
project.godot          configuração (1280x720, tela deitada, renderer Compatibility p/ mobile)
scenes/main.tscn       cena principal
scripts/
  main.gd              monta a fase e controla pedidos, tempo, gasolina e pontuação
  game_config.gd       balanceamento (dificuldades, gasolina, pontos, obstáculos) e paleta de cores
  level_data.gd        layout do mapa: chão, restaurantes, casas, postos e obstáculos
  obstaculos.gd        lógica do M2: lombada, boca de lobo, terra, ciclovia, blitz, cruzamento, chuva, CET
  marcador.gd          desenho dos obstáculos na pista (e o semáforo/carro do cruzamento)
  carro_cet.gd         carro da CET que persegue o entregador
  chuva.gd             efeito de chuva
  fachada.gd           construções decorativas (sobrados, lojas, bares, prédios...)
  moto.gd              física e desenho da moto
  ground.gd            chão com rampas, calçada e postes
  block.gd             obstáculos sólidos (caçamba, caixote, cone)
  location.gd          restaurantes, casas e postos
  skyline.gd           prédios do fundo (parallax)
  hud.gd               interface durante o jogo + setas para o destino
  code_popup.gd        balão do cliente com teclado numérico
  code_display.gd      números "quebradiços" do código
  screens.gd           menu (escolha da bag) e tela de fim
  touch_controls.gd    botões de toque para celular
  ui_util.gd           helpers de interface
docs/GDD.md            documento de design
```

Toda a arte do protótipo é desenhada por código (sem imagens), para poder trocar por sprites depois sem mudar a lógica.

## Exportar (PC / Android)

No Godot: **Editor → Gerenciar modelos de exportação** → baixar os templates. Depois **Projeto → Exportar** e adicionar os presets *Windows Desktop* e *Android*. Android exige também o SDK do Android e o JDK configurados (**Editor → Configurações do Editor → Exportar → Android**).

## Status

- **M1 (núcleo):** moto, coleta → entrega, prazo com bônus de tempo, gasolina com postos aleatórios, código no portão, pontuação, 3 dificuldades (bags), suporte a toque.
- **M2 (obstáculos):** lombada e boca de lobo com equilíbrio no ar, estrada de terra, ciclovia, cruzamento com semáforo, blitz, chuva, perseguição da CET e mapa com o dobro do tamanho.
