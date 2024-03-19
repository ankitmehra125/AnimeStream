import 'dart:async';

import 'package:animestream/core/commons/types.dart';
import 'package:animestream/core/data/watching.dart';
import 'package:animestream/ui/models/customControls.dart';
import 'package:animestream/ui/models/sources.dart';
import 'package:animestream/ui/pages/settingPages/player.dart';
import 'package:animestream/ui/theme/mainTheme.dart';
import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';
import 'package:flutter/services.dart';

class Watch extends StatefulWidget {
  final String selectedSource;
  final WatchPageInfo info;
  final List<String> episodes;
  const Watch({
    super.key,
    required this.selectedSource,
    required this.info,
    required this.episodes,
  });

  @override
  State<Watch> createState() => _WatchState();
}

class _WatchState extends State<Watch> with TickerProviderStateMixin {
  late BetterPlayerController _controller;

  bool _visible = true;
  bool _controlsDisabled = false;
  Timer? _controlsTimer;
  String currentQualityLink = '';
  List<String> epLinks = [];
  late WatchPageInfo info;
  int currentEpIndex = 0;
  bool controlsLocked = false;

  List qualities = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    info = widget.info;
    currentEpIndex = info.episodeNumber - 1;
    epLinks = widget.episodes;

    getQualities().then((val) => changeQuality(qualities[0]['link'],
        _controller.videoPlayerController!.value.position.inSeconds));

    final config = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      expandToFill: true,
      autoPlay: true,
      autoDispose: true,
    );

    _controller = BetterPlayerController(config);

    playVideo(info.streamInfo.link);

    _controller.setBetterPlayerControlsConfiguration(
      BetterPlayerControlsConfiguration(
        playerTheme: BetterPlayerTheme.custom,
        showControls: false,
      ),
    );
  }

  Future<dynamic> playVideo(String url) async {
    await _controller.setupDataSource(
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        info.streamInfo.link,
        bufferingConfiguration: BetterPlayerBufferingConfiguration(
          maxBufferMs: 40000,
        ),
      ),
    );
  }

  bool isControlsLocked() {
    return controlsLocked;
  }

  Future<void> refreshPage(int episodeIndex, dynamic streamInfo) async {
    info.streamInfo = streamInfo;
    qualities = [];
    bool shouldUpdate = currentEpIndex < episodeIndex;
    await getQualities();
    setState(() {
      info.episodeNumber = episodeIndex + 1;
      currentEpIndex = episodeIndex;
    });
    if (shouldUpdate)
      await updateWatching(
        widget.info.id,
        info.animeTitle,
        episodeIndex + 1,
      );
  }

  Future<void> updateWatchProgress(int episodeIndex) async {
    await updateWatching(
      widget.info.id,
      info.animeTitle,
      episodeIndex + 1,
    );
  }

  Future getEpisodeSources(
      String epLink, Function(List<dynamic>, bool) cb) async {
    // final List<dynamic> srcs = [];
    await getStreams(widget.selectedSource, epLink, cb);
    // return srcs;
  }

  Future<void> getQualities() async {
    final List list =
        await generateQualitiesForMultiQuality(info.streamInfo.link);
    if (mounted)
      setState(() {
        qualities = list;
      });
  }

  void changeQuality(String link, int? currentTime) async {
    if (currentQualityLink != link) {
      playVideo(link);
      _controller.videoPlayerController
          ?.seekTo(Duration(seconds: currentTime ?? 0));
      currentQualityLink = link;
    }
  }

  void toggleControls(bool value) async {
    await Future.delayed(
      Duration(milliseconds: 100),
    );
    setState(() {
      _controlsDisabled = value;
    });
  }

  void hideControlsOnTimeout() {
    if (_visible) {
      if (_controlsTimer != null) {
        _controlsTimer!.cancel();
      }
      _controlsTimer = Timer(Duration(seconds: 5), () {
        if (mounted)
          setState(() {
            _visible = false;
            toggleControls(true);
          });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _visible = !_visible;
          toggleControls(!_visible);
          hideControlsOnTimeout();
        });
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // GestureDetector(
            //   onTap: () {
            //     setState(() {
            //       _visible = !_visible;
            //       toggleControls(!_visible);
            //       hideControlsOnTimeout();
            //     });
            //   },
            //   child:
            BetterPlayer(
              controller: _controller,
            ),
            // ),
            AnimatedOpacity(
              opacity: _visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Stack(
                children: [
                  IgnorePointer(ignoring: true, child: overlay()),
                  IgnorePointer(
                    ignoring: _controlsDisabled,
                    child: Controls(
                      controller: _controller,
                      bottomControls: bottomControls(),
                      topControls: topControls(),
                      episode: {
                        'getEpisodeSources': getEpisodeSources,
                        'epLinks': epLinks,
                        'currentEpIndex': currentEpIndex,
                      },
                      refreshPage: refreshPage,
                      updateWatchProgress: updateWatchProgress,
                      isControlsLocked: isControlsLocked,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Expanded topControls() {
    return Expanded(
      child: Container(
        alignment: Alignment.topCenter,
        child: Container(
          height: 50,
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(left: 20, top: 5),
                      alignment: Alignment.topLeft,
                      child: Text("Episode ${info.episodeNumber}",
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'NotoSans',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 20),
                      alignment: Alignment.topLeft,
                      child: Text(
                        "${info.animeTitle}",
                        style: TextStyle(
                          color: Color.fromARGB(255, 190, 190, 190),
                          fontFamily: 'NotoSans',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    controlsLocked = !controlsLocked;
                  });
                },
                icon: Icon(
                  !controlsLocked
                      ? Icons.lock_open_rounded
                      : Icons.lock_rounded,
                  color: textMainColor,
                ),
              ),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      backgroundColor: Colors.black,
                      contentTextStyle: TextStyle(color: Colors.white),
                      title: Text("Stream info",
                          style: TextStyle(color: accentColor)),
                      content: Text(
                        //Resolution: ${qualities.where((element) => element['link'] == currentQualityLink).toList()[0]?? ['resolution'] ?? ''}   idk
                        "Aspect Ratio: 16:9 (probably) \nServer: ${widget.selectedSource} \nSource: ${info.streamInfo.server} ${info.streamInfo.backup ? "\(backup\)" : ''}",
                      ),
                    ),
                  );
                },
                icon: Icon(
                  Icons.info_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //idea: use this in customControls file!
  Container overlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [
              Color.fromARGB(180, 0, 0, 0),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.7]),
      ),
      child: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [
                  Color.fromARGB(180, 0, 0, 0),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: [0.0, 0.7])),
      ),
    );
  }

  Container bottomControls() {
    return Container(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                isScrollControlled: true,
                context: context,
                backgroundColor: Colors.black,
                showDragHandle: false,
                barrierColor: Color.fromARGB(17, 255, 255, 255),
                builder: (BuildContext context) {
                  return Container(
                    width: 400,
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            "Choose Quality",
                            style: TextStyle(
                                color: textMainColor,
                                fontFamily: "Rubik",
                                fontSize: 20),
                          ),
                        ),
                        ListView.builder(
                          itemCount: qualities.length,
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemBuilder: (BuildContext context, index) {
                            return Container(
                              padding: EdgeInsets.only(left: 25, right: 25),
                              child: ElevatedButton(
                                onPressed: () async {
                                  final src = qualities[index]['link'];
                                  changeQuality(
                                      src,
                                      _controller.videoPlayerController!.value
                                          .position.inSeconds);
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    // side: BorderSide(color: Colors.white)
                                  ),
                                  backgroundColor: qualities[index]['link'] ==
                                          currentQualityLink
                                      ? accentColor
                                      : Color.fromARGB(78, 7, 7, 7),
                                ),
                                child: Text(
                                  "${qualities[index]['quality']}p",
                                  style: TextStyle(
                                    color: qualities[index]['link'] ==
                                            currentQualityLink
                                        ? Colors.black
                                        : accentColor,
                                    fontFamily: "Poppins",
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            icon: Icon(
              Icons.high_quality_rounded,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => PlayerSetting()));
                },
                icon: Icon(
                  Icons.video_settings_rounded,
                  color: textMainColor,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft
    ]);
    super.dispose();
  }
}
