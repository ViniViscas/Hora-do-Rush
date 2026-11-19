# Hora do Rush

Jogo de plataforma 2D de motoqueiro entregador — Trabalho A3.

## Identificação

| | |
|---|---|
| **Jogo** | Hora do Rush |
| **Grupo** | *(nome do grupo a definir)* |
| **Disciplina (UC)** | Usabilidade, desenvolvimento web, mobile e jogos |
| **Professor** | Elzo Brito dos Santos Filho |

| Integrante | RA |
|---|---|
| Anna Carolina Martins | 823214726 |
| Pedro Henrique Nascimento | 826221314 |
| Isaías de Lima Gomes | 823151518 |
| Vinícius Viscardi Silveira | 823153528 |
| Júlia Silva de Araújo | 823122431 |

## Descrição

Você é um motoboy de aplicativo em São Paulo, no pior horário do dia: a hora do rush. Colete pedidos nos restaurantes, atravesse a cidade desviando de lombadas, bocas de lobo, cruzamentos, blitzes e da CET (sua CNH venceu...) e entregue no portão do cliente dentro do prazo, digitando o código "quebradiço" do pedido. Cada entrega rápida devolve tempo ao relógio; errar custa pontos. E se a gasolina acabar, o turno acaba junto.

São 5 fases por bag (dificuldade), cada uma com mais entregas e mais perigos. O dinheiro de cada turno paga melhorias da moto na oficina.

O design completo está em [`docs/GDD.md`](docs/GDD.md).

## Como rodar

### Pré-requisitos

- **Godot Engine 4.7.2**, versão padrão (**não** a versão .NET/C#): <https://godotengine.org/download>
  - No Windows também dá pelo terminal: `winget install GodotEngine.GodotEngine`
- Computador com placa de vídeo compatível com **OpenGL 3.3** (o jogo usa o renderizador *Compatibility*, o mais leve do Godot).
- Testado no **Windows 11 (64 bits)**.
- Não há outras dependências: nenhuma biblioteca, imagem ou arquivo de som externo (a única fonte usada já vem na pasta `assets/fontes/`). O Godot é o equivalente ao `requirements.txt` deste projeto.

### Rodando pelo código-fonte

1. Baixe ou clone este repositório.
2. Abra o Godot → **Importar** → selecione o arquivo `project.godot` desta pasta → **Importar e editar**.
3. Aperte **F5** (ou o botão ▶ no canto superior direito) para jogar.

Também dá para rodar direto pelo terminal, de dentro da pasta do projeto: `godot --path .`

### Rodando pelo executável (Windows)

O `HoraDoRush.exe` é gerado pela exportação (seção [Exportar](#exportar-pc--android)) e roda sem instalar nada.

## Controles

| Ação | PC | Celular |
|---|---|---|
| Pilotar | `A` / `D` ou setas | botões `<` `>` |
| Freio | `S`, `↓` ou `Shift` | botão FREIO |
| Pulo | `Espaço`, `W` ou `↑` | botão PULO |
| Equilibrar no ar (após lombada / boca de lobo) | `A` / `D` | botões `<` `>` |
| Código no portão | teclas numéricas (`Backspace` apaga) | teclado na tela |
| Pausar / continuar | `P` ou `Esc` | botão `II` |
| Liga/desliga o som | `M` | — |
| Avançar a cutscene / pular | `Espaço`, `Enter` ou clique / `Esc` | toque / botão PULAR |
| Menus | mouse | toque |

Os controles também aparecem na tela inicial do jogo. Os botões de toque aparecem automaticamente no celular. Para vê-los no PC, rode com o argumento `-- --toque`.

## Regras

### História

**Felipe**, motoboy da periferia de São Paulo, quer mudar de vida: virar o melhor entregador da cidade e juntar dinheiro para comprar a própria casa. A **Tati**, mecânica de uma oficina de bairro, conserta a moto velha dele em troca do pagamento das entregas e investe cada real que sobra na máquina.

Cada bag é um **capítulo** da história, com prazos cada vez mais apertados e mais estresse:

| Capítulo | Bag | Objetivo do Felipe |
|---|---|---|
| 1. A casa | iFudê (fácil) | Juntar a entrada da casa própria |
| 2. A reforma | 99 Problemas (médio) | Reformar a casa e subir a laje |
| 3. A oficina | Kitreta (difícil) | Salvar a oficina da Tati, que vai fechar |

Fechar a fase 5 de um capítulo libera o seguinte. A história aparece em **cutscenes**:
- **abertura do capítulo**, na primeira vez que se escolhe a bag (dá para rever no botão HISTÓRIA da tela de fases);
- **cartão antes de cada fase**, na primeira vez que ela é jogada, com texto próprio de cada capítulo;
- **final do capítulo** ao fechar a fase 5;
- **imagens nas telas de derrota** (sem gasolina, tempo esgotado).

### Objetivo e fluxo de uma entrega

```
Pegar o pedido no restaurante → Atravessar a rua (obstáculos, gasolina) → Parar no endereço
→ Esperar o cliente no portão → Digitar o código → Entregar (pontos + tempo de volta) → próximo pedido
```

- Uma seta na tela aponta para o destino atual (restaurante ou casa), com a distância em metros.
- Para coletar ou entregar, é preciso **parar** em frente ao local. Às vezes a cozinha atrasa o pedido ou o cliente demora a descer.
- No portão, o cliente pede o **código do pedido**, que aparece com números tremidos e distorcidos. Errar o código tira pontos e é preciso digitar de novo.

### Como ganhar e como perder

- **Vitória:** fazer todas as entregas da fase antes de o tempo acabar.
- **Derrota:** o **tempo** chegar a zero, ou a **gasolina** acabar (game over na hora, sem exceção).
- Não existem vidas: errar custa pontos e tempo, não a partida.

### Fases e dificuldade

- A **bag** escolhida no menu é o capítulo e a dificuldade: **iFudê** (fácil), **99 Problemas** (médio) e **Kitreta** (difícil). Ela define o tempo, o prazo dos pedidos e a frequência dos percalços. O capítulo 2 libera ao fechar o 1, e o 3 ao fechar o 2 (para liberar todos desde o início: `CAPITULOS_EM_ORDEM = false` em `src/game_config.gd`).
- Cada bag tem uma **campanha de 5 fases**. Vencer uma fase libera a próxima, e as já vencidas podem ser rejogadas.

| Fase | Nome | Entregas | O que aparece |
|---|---|---|---|
| 1 | Primeiro dia | 3 | Lombadas, bocas de lobo, terra e cruzamentos |
| 2 | Pegando o jeito | 4 | Entra a blitz |
| 3 | Sexta à noite | 5 | Entram a chuva e a CET |
| 4 | Véspera de feriado | 6 | Mais obstáculos e blitz mais rigorosa |
| 5 | Hora do Rush | 7 | Rua lotada, mais chuva e relógio apertado |

### Tempo e prazo

- Cada pedido tem um **prazo**. Entregar antes do prazo **devolve tempo ao relógio da fase** (segundos que sobraram × 2,5 no fácil, × 2 no médio, × 1,5 no difícil).
- Entregar depois do prazo vale menos pontos, mas não tira tempo.

### Gasolina

- A moto gasta gasolina andando, e mais em alta velocidade. Abaixo de 30%, uma seta mostra o posto mais perto.
- Para abastecer, pare no posto: encher do zero leva cerca de 10 segundos, e o relógio continua correndo.
- Os postos mudam de lugar a cada partida.

### Pontuação

| Ganha | Pontos |
|---|---|
| Entrega no prazo | +100, mais 5 por segundo que sobrou do prazo |
| Entrega atrasada | +40 |
| Pousar a moto depois de voar numa lombada | +10 ou mais (cresce com o tempo no ar; pouso quase reto vale ×1,5) |
| Segurar firme depois de uma boca de lobo | +10 |
| Fugir da CET | +50 |
| Terminar a fase | +2 por segundo que sobrou no relógio |

| Perde | Pontos |
|---|---|
| Cair da moto depois da lombada | -40 |
| Cair da moto na boca de lobo | -30 |
| Ser pego pelo carro no cruzamento (semáforo vermelho) | -50 |
| Ser pego pela CET | -60 e -8 segundos |
| Errar o código | -25 |

- **Blitz:** passar devagar é seguro; passar rápido aumenta muito a chance de ser parado por alguns segundos.
- **Lombada e boca de lobo** jogam a moto para o alto: use `A` / `D` no ar para equilibrar e pousar reto. Cada uma só dá bônus uma vez por pedido.
- **Estrada de terra** deixa a moto lenta; **ciclovia** (quando aparece) deixa mais rápida; **chuva** deixa o freio fraco.

### Dinheiro e oficina

- No fim da fase vem o **acerto do turno**: vencendo, R$ 1 a cada 10 pontos; perdendo, só R$ 8 por entrega feita.
- Na **oficina** o dinheiro compra melhorias para a moto, com 3 níveis cada: **motor**, **freio**, **tanque**, **amortecedor** e **bag térmica**.
- O progresso (fases, dinheiro, melhorias e recordes) fica salvo em arquivo, separado por bag: `user://progresso.cfg` (no Windows: `%APPDATA%\Godot\app_userdata\Hora do Rush\`). Para zerar, é só apagar esse arquivo.

## Tecnologia

- **Motor:** [Godot Engine](https://godotengine.org) 4.7.2 (software livre, licença MIT).
- **Linguagem:** GDScript, a linguagem de script do próprio Godot (sintaxe parecida com Python).
- **Renderizador:** *Compatibility* (OpenGL), que roda em PCs mais simples e em celulares.

**Por que Godot e não pygame:** o Godot é um motor feito especificamente para jogos, e isso deixou o desenvolvimento mais confortável para o grupo. Ele já traz de fábrica:
- física 2D (gravidade, colisão e corpos como `CharacterBody2D`);
- sistema de cenas e nós;
- câmera que segue o jogador;
- interface (botões, textos);
- áudio;
- suporte a toque;
- exportação para Windows e Android.

Com isso o grupo pôde se concentrar nas regras e na jogabilidade em vez de reconstruir essas bases. Toda a lógica do jogo (pedidos, obstáculos, fases, pontuação, geração do mapa, desenho e sons) foi escrita no projeto, sem bibliotecas de terceiros.

Cada fase tem um mapa fixo dentro da campanha (o número aparece na tela de fim). Para forçar um mapa específico, rode com `-- --semente=N`.

## Estrutura

```
project.godot          configuração (1280x720, tela deitada, renderer Compatibility p/ mobile)
scenes/main.tscn       cena principal
src/
  main.gd              monta a fase e controla pedidos, tempo, gasolina e pontuação
  game_config.gd       balanceamento (dificuldades, fases, melhorias, gasolina, pontos) e paleta de cores
  progresso.gd         campanha salva em disco: fases liberadas, dinheiro, melhorias, recordes
  som.gd               sons e músicas sintetizados por código (efeitos, motor, funk da partida)
  gerador_fase.gd      gera o mapa por semente: chão, endereços e obstáculos (regras de distância em FOLGAS)
  obstaculos.gd        lógica do M2: lombada, boca de lobo, terra, ciclovia, blitz, cruzamento, chuva, CET
  marcador.gd          desenho dos obstáculos na pista (e o semáforo/carro do cruzamento)
  carro_cet.gd         carro da CET que persegue o entregador
  chuva.gd             efeito de chuva
  fachada.gd           construções decorativas (sobrados, lojas, bares, prédios...)
  sujeira.gd           texturas "sujas": umidade, reboco caído, pichação, lambe-lambe, lixo
  efeitos.gd           feedback visual: poeira, faíscas, confete e pontos flutuando
  moto.gd              física e desenho da moto
  ground.gd            chão com rampas, calçada e postes
  block.gd             obstáculos sólidos (caçamba, caixote, cone)
  location.gd          restaurantes, casas e postos
  skyline.gd           prédios do fundo (parallax)
  hud.gd               interface durante o jogo + setas para o destino
  code_popup.gd        balão do cliente com teclado numérico
  code_display.gd      números "quebradiços" do código
  screens.gd           menu (escolha da bag), fases, pausa e tela de fim
  tela_oficina.gd      oficina: fundo, a mecânica Tati comentando as melhorias e o painel de compra
  personagem.gd        mecânica e entregador em pixel art desenhada por código
  historia.gd          roteiro das cutscenes (falas e imagens de cada cena)
  cutscene.gd          exibição das cutscenes: imagem, caixa de texto, avançar e pular
  touch_controls.gd    botões de toque para celular
  ui_util.gd           helpers de interface
assets/fontes/         fonte pixelada Silkscreen Bold + licença (OFL.txt)
assets/img/            fundo da oficina e imagens das cutscenes (cutscenes/), geradas com IA
                       (não há assets/sons/: todos os sons são gerados por código em src/som.gd)
docs/GDD.md            documento de design
```

Toda a arte do protótipo é desenhada por código (sem imagens), para poder trocar por sprites depois sem mudar a lógica.

## Exportar (PC / Android)

No Godot: **Editor → Gerenciar modelos de exportação** → baixar os templates (versão 4.7.2).

**Windows:** o preset *Windows Desktop* já vem configurado em `export_presets.cfg`. Use **Projeto → Exportar → Exportar projeto**, ou pelo terminal:

```
godot --headless --path . --export-release "Windows Desktop" builds/windows/HoraDoRush.exe
```

Sai um único `HoraDoRush.exe` (o jogo vai embutido), que roda sem instalar nada. A pasta `builds/` fica fora do Git.

**Android (ainda não configurado):** adicionar o preset *Android* em **Projeto → Exportar**. Android exige também o SDK do Android e o JDK configurados (**Editor → Configurações do Editor → Exportar → Android**).

## Status

- **M1 (núcleo):** moto, coleta → entrega, prazo com bônus de tempo, gasolina com postos aleatórios, código no portão, pontuação, 3 dificuldades (bags), suporte a toque.
- **M2 (obstáculos):** lombada e boca de lobo com equilíbrio no ar, estrada de terra, ciclovia, cruzamento com semáforo, blitz, chuva, perseguição da CET e mapa com o dobro do tamanho.
- **M2.5 (mapa procedural):** a rua é gerada a cada partida, com distâncias mínimas entre os obstáculos.
- **M3 (parcial):** campanha de 5 fases em sequência por bag, com densidade de obstáculos crescente.
- **M4 (parcial):** dinheiro por fase e oficina com 5 melhorias de 3 níveis.

## Créditos

Não há arquivos de áudio de terceiros. Os únicos arquivos externos ao código são a fonte e as imagens (fundo da oficina e cutscenes), geradas com IA.

- **Arte:** toda desenhada por código (formas e cores em `_draw()`).
- **Sons e músicas:** todos sintetizados por código em `src/som.gd` (ondas senoidais, quadradas, serra e ruído), sem nenhuma gravação. Inclui a trilha do menu e o funk paulista da partida.
- **Fundo da oficina:** `assets/img/oficina_fundo.jpg`, gerado pelo grupo com IA (**Google Gemini**). A mecânica e o entregador que aparecem por cima são desenhados por código.
- **Cutscenes da história:** `assets/img/cutscenes/*.jpg`, geradas pelo grupo com IA (**Google Gemini**), a partir dos prompts do roteiro e usando o fundo da oficina como referência de estilo e de personagens.
- **Fonte:** *Silkscreen Bold*, de Jason Kottke (The Silkscreen Project Authors) — arquivo `assets/fontes/Silkscreen-Bold.ttf`, obtido em <https://fonts.google.com/specimen/Silkscreen> (repositório <https://github.com/googlefonts/silkscreen>). Licença **SIL Open Font License 1.1**, texto completo em `assets/fontes/OFL.txt`.

## Uso de IA

**Foi utilizada IA neste projeto.** A maior parte do código foi escrita com o **Claude Code** (assistente de programação da Anthropic, modelo Claude Opus), a partir das ideias, das decisões e dos testes do grupo.

| Para quê | Arquivos |
|---|---|
| Escrever a maior parte do código do jogo (lógica, física da moto, obstáculos, interface, fases, oficina) | `src/*.gd`, `scenes/main.tscn` |
| Geração procedural do mapa (regras de distância entre obstáculos) | `src/gerador_fase.gd` |
| Arte desenhada por código (moto, fachadas, texturas sujas, animações, efeitos, HUD) | `src/moto.gd`, `src/fachada.gd`, `src/sujeira.gd`, `src/efeitos.gd`, `src/ground.gd`, `src/location.gd`, `src/hud.gd` e outros |
| Sons e músicas sintetizados por código | `src/som.gd` |
| Robôs de teste (partidas automáticas para balancear dificuldade e fases) | fora do repositório |
| Redação e organização da documentação | `README.md`, `docs/GDD.md` |
| Configuração da exportação para Windows | `export_presets.cfg` |
| Roteiro da história (a partir dos pontos definidos pelo grupo) e prompts de imagem das cutscenes | roteiro das cutscenes |

Também foi usado o **Google Gemini** (geração de imagens) para as imagens do jogo:

| Para quê | Arquivos |
|---|---|
| Fundo da oficina, em pixel art | `assets/img/oficina_fundo.jpg` |
| Imagens das cutscenes (introdução, cartões das fases e finais) | `assets/img/cutscenes/*.jpg` |

**O que veio do grupo:** a ideia do jogo e as mecânicas originais (ver `docs/GDD.md`), os pontos-chave da história (Felipe, a mecânica Tati e o sonho da casa própria), as decisões de design e de balanceamento, os nomes das bags, a geração e escolha das imagens, os testes jogando e a revisão do que foi gerado.

O grupo revisou o código gerado e deve saber explicá-lo na apresentação.
