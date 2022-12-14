import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../models/message/chatmodel.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../secrets.dart';

class ChatScreen extends StatefulWidget {
  int chatroomID;
  int loginID;
  int friendID;
  String friendName;
  String friendImage;

  ChatScreen(
      {Key? key,
      required this.chatroomID,
      required this.loginID,
      required this.friendID,
      required this.friendName,
      required this.friendImage})
      : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static final storage = FlutterSecureStorage();
  dynamic userInfo = '';
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int? myConnId;
  int? friendConnId;
  final StreamController _streamController = StreamController();
  int? notReadCnt;

  getChatReadCnts() async {
    try {
      var dio = Dio();
      Response response = await dio.get(
          '${API_URL}chatroom/readcnts?id_1=${widget.loginID}&id_2=${widget.friendID}');
      if (response.statusCode == 200) {
        final jsonData = response.data;
        int tempCnt = jsonData['notreadcnt'] == null
            ? 0
            : int.parse(jsonData['notreadcnt']);
        setState(() {
          notReadCnt = tempCnt;
        });
        return await getChatMessages(tempCnt);
      } else {
        return false;
      }
    } on DioError catch (e) {
      final errorjson = jsonDecode(e.response.toString());
      print(errorjson);
      return false;
    }
  }

  getChatConns() async {
    try {
      var dio = Dio();
      Response response = await dio.get(
          '${API_URL}chatroom/conns?id_1=${widget.loginID}&id_2=${widget.friendID}');
      if (response.statusCode == 200) {
        final jsonData = response.data;
        setState(() {
          myConnId = jsonData[0];
          friendConnId = jsonData[1];
        });
        // print("?????????");
        socket.emit(
            'reset', {'chatroomID': widget.chatroomID, 'connid': jsonData[0]});
      } else {
        return false;
      }
    } on DioError catch (e) {
      final errorjson = jsonDecode(e.response.toString());
      return false;
    }
  }

  getChatMessages(int notReadCnt) async {
    try {
      var dio = Dio();
      Response response = await dio
          .get('${API_URL}chatroom/message?room_id=${widget.chatroomID}');
      if (response.statusCode == 200) {
        final jsonData = response.data;
        List<ChatModel> temp = [];
        int totalSends =
            jsonData.where((c) => c['sender'] == widget.loginID).length;
        int i = totalSends;
        jsonData.forEach((e) {
          var nowtime = DateTime.parse(e['sendat']);
          var realnow = DateTime.now();
          Duration diff = realnow.difference(nowtime);
          bool nowisread = true;
          if (e['sender'] == widget.loginID) {
            if (i <= notReadCnt) {
              nowisread = false;
            }
            i -= 1;
          }
          ChatModel thisMsg = ChatModel(
              chatroomID: widget.chatroomID,
              senderID: e['sender'],
              receiverID: 0,
              sentAt: e['sendat'],
              messagetext: e['messagetext'],
              isread: nowisread); // e['isread]
          temp.add(thisMsg);
        });
        setState(() {
          _messages = temp;
          _streamController.add(_messages);
        });
        return true;
      } else {
        print('error');
        return false;
      }
    } on DioError catch (e) {
      final errorjson = jsonDecode(e.response.toString());
      print(errorjson);
      return false;
    }
  }

  var channel;
  List<ChatModel> _messages = [];

  addMessage(msg) {
    setState(() {
      _messages.add(msg);
    });
    _streamController.add(_messages);
  }

  final bool _showSpinner = false;
  final bool _showVisibleWidget = false;
  final bool _showErrorIcon = false;
  bool socketFlag = false;
  String hintmsg = 'Loading...';

  void setStateIfMounted(f) {
    if (mounted) setState(f);
  }

  dynamic socket;

  initializeSocket() {
    try {
      socket = io('http://34.64.217.3:3000/', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      channel = socket.connect();
      socket.on('connect', (data) {
        debugPrint('socket connected');
        // debugPrint(socket.connected);
        print('????????????');
        socket.emit('join', widget.chatroomID);
        setState(() {
          socketFlag = true;
          hintmsg = 'Write message...';
        });
        debugPrint('????????????');
      });

      socket.on('join', (data) {
        debugPrint('socket join');
        debugPrint(data);
      });

      socket.on('leave', (data) {
        debugPrint('socket leave');
      });

      socket.on('reset', (data) {
        debugPrint('socket reset');
        // reset => ?????? ?????? ????????? ?????? ????????????
        var newMessages = _messages
            .map((e) => e.isread == false
                ? ChatModel(
                    chatroomID: e.chatroomID,
                    senderID: e.senderID,
                    receiverID: e.receiverID,
                    sentAt: e.sentAt,
                    messagetext: e.messagetext,
                    isread: true)
                : e)
            .toList();
        setState(() {
          _messages = newMessages;
        });
        _streamController.add(newMessages);
      });

      socket.on('message', (data) {
        var message = ChatModel.fromJson(data);
        setStateIfMounted(() {
          _messages.add(message);
          _streamController.add(_messages);
          // socket.emit('reset', myConnId);
          socket.emit(
              'reset', {'chatroomID': widget.chatroomID, 'connid': myConnId});
        });
      });

      socket.on('disconnect', (data) {
        debugPrint('socket disconnected');
        setState(() {
          socketFlag = false;
          hintmsg = 'Disconnected...';
        });
        socket.disconnect();
      });
      // socket.onDisconnect((_) => debugPrint('disconnect'));
    } catch (e) {
      print(e);
    }
  }

  @override
  void initState() {
    print('hello');
    getChatReadCnts();
    getChatConns();
    super.initState();
    // enterChatRoom();
    initializeSocket();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
          appBar: AppBar(
            elevation: 1,
            automaticallyImplyLeading: false,
            // backgroundColor: const Color(0xFF271160),
            backgroundColor: Colors.white,
            flexibleSpace: SafeArea(
              child: Container(
                padding: EdgeInsets.only(right: 16),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () {
                        socket.emit('leave', widget.chatroomID);
                        socket.emit('disconnect'); // ?????? socket.disconnect()??? ??????
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        Icons.arrow_back,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(
                      width: 2,
                    ),
                    GestureDetector(
                      onTap: () {
                        // Navigator.pushNamed(context, '/contacts');
                      },
                      child: CircleAvatar(
                        // ???????????????
                        backgroundImage: NetworkImage(widget.friendImage),
                        maxRadius: 20,
                      ),
                    ),
                    SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            widget.friendName,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(
                            height: 6,
                          ),
                          Text(
                            'Online',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.settings,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // appBar: AppBar(
          //     centerTitle: true,
          //     title: const Text('Chat Screen'),
          //     backgroundColor: const Color(0xFF271160)),
          body: SingleChildScrollView(
            reverse: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                StreamBuilder(
                    stream: _streamController.stream,
                    initialData: [],
                    builder: (BuildContext context, AsyncSnapshot snapshot) {
                      if (snapshot.hasData) {
                        List nowMessages = snapshot.data;
                        return ListView.builder(
                          // controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          // reverse: _messages.isEmpty ? false : true,
                          itemCount: 1,
                          shrinkWrap: true,
                          itemBuilder: (BuildContext context, int index) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                  top: 10, left: 10, right: 10, bottom: 3),
                              child: Column(
                                mainAxisAlignment: nowMessages.isEmpty
                                    ? MainAxisAlignment.center
                                    : MainAxisAlignment.start,
                                children: <Widget>[
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: nowMessages.map((message) {
                                        return ChatBubble(
                                            date: message.sentAt,
                                            message: message.messagetext,
                                            isMe: message.senderID ==
                                                widget.loginID,
                                            isRead: message.isread);
                                      }).toList()),
                                ],
                              ),
                            );
                          },
                        );
                      } else {
                        return Container(
                          alignment: Alignment.center,
                          height: 200,
                          child:
                              Text('?????? ???????????? :)', textAlign: TextAlign.center),
                        );
                      }
                    }),
                // ListView.builder(
                //   // controller: _scrollController,
                //   physics: const BouncingScrollPhysics(),
                //   // reverse: _messages.isEmpty ? false : true,
                //   itemCount: 1,
                //   shrinkWrap: true,
                //   itemBuilder: (BuildContext context, int index) {
                //     return Padding(
                //       padding: const EdgeInsets.only(
                //           top: 10, left: 10, right: 10, bottom: 3),
                //       child: Column(
                //         mainAxisAlignment: _messages.isEmpty
                //             ? MainAxisAlignment.center
                //             : MainAxisAlignment.start,
                //         children: <Widget>[
                //           Column(
                //               crossAxisAlignment: CrossAxisAlignment.stretch,
                //               children: _messages.map((message) {
                //                 print('gogo$message');
                //                 return ChatBubble(
                //                     date: message.sentAt,
                //                     message: message.messagetext,
                //                     // isMe: message.socketId ==
                //                     //     socket
                //                     //         .id, // message.userId == ????????????????????????
                //                     isMe: message.senderID == widget.loginID,
                //                     isRead: message.isread);
                //               }).toList()),
                //         ],
                //       ),
                //     );
                //   },
                // ),
                // ListView.builder(
                //   // controller: _scrollController,
                //   physics: const BouncingScrollPhysics(),
                //   // reverse: _messages.isEmpty ? false : true,
                //   itemCount: 1,
                //   shrinkWrap: true,
                //   itemBuilder: (BuildContext context, int index) {
                //     return Padding(
                //       padding: const EdgeInsets.only(
                //           top: 10, left: 10, right: 10, bottom: 3),
                //       child: Column(
                //         mainAxisAlignment: _messages.isEmpty
                //             ? MainAxisAlignment.center
                //             : MainAxisAlignment.start,
                //         children: <Widget>[
                //           Column(
                //               crossAxisAlignment: CrossAxisAlignment.stretch,
                //               children: _messages.map((message) {
                //                 print('gogo$message');
                //                 return ChatBubble(
                //                     date: message.sentAt,
                //                     message: message.messagetext,
                //                     // isMe: message.socketId ==
                //                     //     socket
                //                     //         .id, // message.userId == ????????????????????????
                //                     isMe: message.senderID == widget.loginID,
                //                     isRead: message.isread);
                //               }).toList()),
                //         ],
                //       ),
                //     );
                //   },
                // ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20,
                  right: 10,
                  top: 5),
              child: Container(
                height: 50,
                width: MediaQuery.of(context).size.width,
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onTap: () {},
                        decoration: InputDecoration.collapsed(
                            enabled: socketFlag ? true : false,
                            hintText: hintmsg,
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none),
                        controller: _messageController,
                        scrollPadding: EdgeInsets.only(bottom: 40),
                      ),
                    ), // Send Button
                    SizedBox(
                      height: 43,
                      width: 42,
                      child: FloatingActionButton(
                        backgroundColor: const Color(0xFF271160),
                        onPressed: () async {
                          if (_messageController.text.trim().isNotEmpty) {
                            String message = _messageController.text.trim();

                            ChatModel nowSend = ChatModel(
                                // socketId: socket.id!,
                                chatroomID: widget.chatroomID,
                                messagetext: message,
                                senderID: widget.loginID,
                                receiverID: widget.friendID,
                                sentAt: DateTime.now()
                                    .toLocal()
                                    .toString()
                                    .substring(0, 16),
                                isread: false);

                            socket.emit('message', nowSend.toJson());
                            addMessage(nowSend); // ?????? ????????? ???????????????.

                            // POST ????????? ?????? DB??? ?????? ????????? ????????? ???????????? ????????????

                            // ????????? ????????? ???????????????
                            _messageController.clear();
                          } else {
                            print(
                                '???????????????: ${_messages.where((e) => e.isread = false).length}');
                          }
                        },
                        mini: true,
                        child: Transform.rotate(
                            angle: 6, child: const Icon(Icons.send, size: 20)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final bool isMe;
  final String message;
  final String date;
  final bool isRead;

  ChatBubble(
      {Key? key,
      required this.message,
      this.isMe = true,
      required this.date,
      required this.isRead});
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            margin: const EdgeInsets.symmetric(vertical: 5.0),
            constraints: BoxConstraints(maxWidth: size.width * .5),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFE3D8FF) : Colors.grey.shade200,
              borderRadius: isMe
                  ? const BorderRadius.only(
                      topRight: Radius.circular(11),
                      topLeft: Radius.circular(11),
                      bottomRight: Radius.circular(0),
                      bottomLeft: Radius.circular(11),
                    )
                  : const BorderRadius.only(
                      topRight: Radius.circular(11),
                      topLeft: Radius.circular(11),
                      bottomRight: Radius.circular(11),
                      bottomLeft: Radius.circular(0),
                    ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  message,
                  textAlign: TextAlign.start,
                  softWrap: true,
                  style:
                      // const TextStyle(color: Color(0xFF2E1963), fontSize: 14),
                      const TextStyle(color: Color(0xFF000000), fontSize: 14),
                ),
                // ?????? ??????
                // Align(
                //   alignment: Alignment.centerRight,
                //   child: Padding(
                //     padding: const EdgeInsets.only(top: 7),
                //     child: Text(
                //       date ?? '',
                //       textAlign: TextAlign.end,
                //       style: const TextStyle(
                //           color: Color(0xFF594097), fontSize: 9),
                //     ),
                //   ),
                // )
              ],
            ),
          ),
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                isMe && !isRead ? '????????????' : '',
                textAlign: TextAlign.end,
                style: const TextStyle(color: Color(0xFF594097), fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
