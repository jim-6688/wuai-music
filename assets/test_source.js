/**
 * @name 测试音源(内置数据)
 * @version 1.0.0
 * @author wuaimusic
 * @description 内置测试数据，无需网络，用于验证音源功能
 * @homepage https://github.com/wuaimusic
 */

// 内置歌曲列表（使用免费CC授权音频）
var _songDatabase = [
  {
    id: '001',
    name: '海阔天空',
    singer: 'Beyond',
    album: '乐与怒',
    interval: 276,
    img: 'https://p2.music.126.net/6y-UleORITEDbvrOLV0Q8A==/5639395138885805.jpg',
    url_128k: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3',
    url_320k: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3',
    url_flac: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3',
  },
  {
    id: '002',
    name: '光辉岁月',
    singer: 'Beyond',
    album: '犹豫',
    interval: 290,
    img: 'https://p1.music.126.net/lfpL1VYMf2LDTK0AZ0v9Gg==/18686200114436760.jpg',
    url_128k: 'https://freetestdata.com/wp-content/uploads/2022/11/Free_Test_Data_500KB_MP3.mp3',
    url_320k: 'https://freetestdata.com/wp-content/uploads/2022/11/Free_Test_Data_500KB_MP3.mp3',
    url_flac: 'https://freetestdata.com/wp-content/uploads/2022/11/Free_Test_Data_500KB_MP3.mp3',
  },
  {
    id: '003',
    name: '真的爱你',
    singer: 'Beyond',
    album: '秘密警察',
    interval: 265,
    img: 'https://p1.music.126.net/0lXMjzB3DOFWLK5o9Y4CtQ==/109951164300687994.jpg',
    url_128k: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3',
    url_320k: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3',
    url_flac: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3',
  },
  {
    id: '004',
    name: '喜欢你',
    singer: 'Beyond',
    album: '亚拉伯跳舞女郎',
    interval: 240,
    img: 'https://p1.music.126.net/bNnPZVq09C6wYFxqOidxBw==/109951163498808474.jpg',
    url_128k: 'https://freetestdata.com/wp-content/uploads/2022/11/Free_Test_Data_500KB_MP3.mp3',
    url_320k: 'https://freetestdata.com/wp-content/uploads/2022/11/Free_Test_Data_500KB_MP3.mp3',
    url_flac: 'https://freetestdata.com/wp-content/uploads/2022/11/Free_Test_Data_500KB_MP3.mp3',
  },
  {
    id: '005',
    name: '不再犹豫',
    singer: 'Beyond',
    album: '犹豫',
    interval: 233,
    img: 'https://p2.music.126.net/6y-UleORITEDbvrOLV0Q8A==/5639395138885805.jpg',
    url_128k: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3',
    url_320k: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3',
    url_flac: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3',
  },
];

// 搜索函数
function searchSongs(keyword) {
  keyword = (keyword || '').toLowerCase();
  if (!keyword) return _songDatabase;
  return _songDatabase.filter(function(s) {
    return s.name.toLowerCase().indexOf(keyword) >= 0 ||
           s.singer.toLowerCase().indexOf(keyword) >= 0 ||
           s.album.toLowerCase().indexOf(keyword) >= 0;
  });
}

// 通过ID查找歌曲
function findSongById(id) {
  for (var i = 0; i < _songDatabase.length; i++) {
    if (_songDatabase[i].id === id || _songDatabase[i].id === String(id)) {
      return _songDatabase[i];
    }
  }
  return null;
}

// 注册 LX Music 事件处理器
lx.on('request', function(params) {
  var source = params.source;
  var action = params.action;
  var info = params.info;

  // 获取任务ID（从 params.taskId，如果存在）
  var taskId = params._taskId;

  // musicUrl: 获取播放地址
  if (action === 'musicUrl') {
    var musicInfo = info.musicInfo || {};
    var quality = info.type || '128k';
    var id = musicInfo.id || musicInfo.songId || '';
    var song = findSongById(id);

    if (!song) {
      setAsyncError(taskId, 'Song not found: ' + id);
      return;
    }

    var url;
    if (quality === 'flac' || quality === 'flac24bit') {
      url = song.url_flac;
    } else if (quality === '320k') {
      url = song.url_320k;
    } else {
      url = song.url_128k;
    }

    setAsyncResult(taskId, url);
    return;
  }

  // lyric: 获取歌词
  if (action === 'lyric') {
    var musicInfo = info.musicInfo || {};
    var id = musicInfo.id || musicInfo.songId || '';
    var song = findSongById(id);

    var lyric = song
      ? '[00:00.00] ' + song.name + '\n[00:05.00] 演唱：' + song.singer + '\n[00:10.00] 测试音源 - 歌词示例\n[00:20.00] 这是一首测试歌曲\n[00:30.00] 用于验证音源功能\n[00:40.00] 如果您看到这行\n[00:50.00] 说明音源工作正常！'
      : '[00:00.00] 暂无歌词';

    setAsyncResult(taskId, { lyric: lyric, tlyric: '' });
    return;
  }

  // pic: 获取封面
  if (action === 'pic') {
    var musicInfo = info.musicInfo || {};
    var id = musicInfo.id || musicInfo.songId || '';
    var song = findSongById(id);
    setAsyncResult(taskId, song ? song.img : null);
    return;
  }

  // search: 搜索歌曲
  if (action === 'search') {
    var keyword = info.keyword || '';
    var results = searchSongs(keyword);
    setAsyncResult(taskId, {
      list: results,
      total: results.length,
    });
    return;
  }

  // leaderboard: 获取榜单列表
  if (action === 'leaderboard') {
    try {
      var boards = [
        { id: 'top_beyond', name: 'Beyond精选', img: 'https://p2.music.126.net/6y-UleORITEDbvrOLV0Q8A==/5639395138885805.jpg', source: 'local', description: 'Beyond乐队经典歌曲' },
      ];
      setAsyncResult(taskId, boards);
    } catch(e) {
      console.log('leaderboard error:', e);
      setAsyncError(taskId, String(e));
    }
    return;
  }

  // leaderboardDetail: 获取榜单详情
  if (action === 'leaderboardDetail') {
    var id = info.id;
    if (id === 'top_beyond') {
      setAsyncResult(taskId, {
        list: _songDatabase,
        updateTime: new Date().toLocaleDateString(),
      });
    } else {
      setAsyncResult(taskId, { list: [], updateTime: '' });
    }
    return;
  }

  setAsyncError(taskId, 'Unknown action: ' + action);
});

// 发送初始化完成事件（同时设置到全局变量）
var _testSourceInitData = {
  sources: {
    local: {
      name: '测试音源',
      type: 'music',
      actions: ['musicUrl', 'lyric', 'pic', 'search', 'leaderboard', 'leaderboardDetail'],
      qualitys: ['128k', '320k', 'flac'],
    }
  },
  openDevTools: false,
};
lx._initData = _testSourceInitData;
lx.send('inited', _testSourceInitData);
