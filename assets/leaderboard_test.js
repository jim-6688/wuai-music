/**
 * @name 榜单测试音源
 * @description 带榜单功能的测试音源，用于验证榜单功能
 * @version 1.0.0
 * @author 吾爱Music
 */

// 模拟榜单数据 - 这里是你需要手动添加的榜单内容
var _leaderboardDatabase = {
  // 热门榜单
  'hot_songs': {
    name: '🔥 热门歌曲',
    description: '全网最热门歌曲排行',
    img: 'https://p2.music.126.net/6y-UleORITEDbvrOLV0Q8A==/5639395138885805.jpg',
    songs: [
      { id: '001', name: '海阔天空', singer: 'Beyond', album: '乐与怒', interval: 276 },
      { id: '002', name: '光辉岁月', singer: 'Beyond', album: '犹豫', interval: 290 },
      { id: '003', name: '真的爱你', singer: 'Beyond', album: '秘密警察', interval: 265 },
      { id: '004', name: '喜欢你', singer: 'Beyond', album: '亚拉伯跳舞女郎', interval: 240 },
      { id: '005', name: '不再犹豫', singer: 'Beyond', album: '犹豫', interval: 233 },
    ]
  },
  // 经典老歌
  'classic_old': {
    name: '📻 经典老歌',
    description: '80/90年代经典回忆',
    img: 'https://p1.music.126.net/lfpL1VYMf2LDTK0AZ0v9Gg==/18686200114436760.jpg',
    songs: [
      { id: '006', name: '千千阙歌', singer: '陈慧娴', album: '永远的朋友', interval: 280 },
      { id: '007', name: '夜半歌声', singer: '张国荣', album: '夜半歌声', interval: 240 },
      { id: '008', name: '倩女幽魂', singer: '张国荣', album: '倩女幽魂', interval: 210 },
    ]
  },
  // 中文流行
  'chinese_pop': {
    name: '🎵 中文流行',
    description: '最新中文流行音乐',
    img: 'https://p1.music.126.net/0lXMjzB3DOFWLK5o9Y4CtQ==/109951164300687994.jpg',
    songs: [
      { id: '009', name: '晴天', singer: '周杰伦', album: '叶惠美', interval: 270 },
      { id: '010', name: '稻香', singer: '周杰伦', album: '依然范特西', interval: 220 },
      { id: '011', name: '七里香', singer: '周杰伦', album: '七里香', interval: 250 },
    ]
  }
};

// 内置歌曲数据库（用于播放）
var _songDatabase = {
  '001': { id: '001', name: '海阔天空', singer: 'Beyond', album: '乐与怒', interval: 276, url: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3' },
  '002': { id: '002', name: '光辉岁月', singer: 'Beyond', album: '犹豫', interval: 290, url: 'https://freetestdata.com/wp-content/uploads/2022/11/Free_Test_Data_500KB_MP3.mp3' },
  '003': { id: '003', name: '真的爱你', singer: 'Beyond', album: '秘密警察', interval: 265, url: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3' },
  '004': { id: '004', name: '喜欢你', singer: 'Beyond', album: '亚拉伯跳舞女郎', interval: 240, url: 'https://freetestdata.com/wp-content/uploads/2022/11/Free_Test_Data_500KB_MP3.mp3' },
  '005': { id: '005', name: '不再犹豫', singer: 'Beyond', album: '犹豫', interval: 233, url: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3' },
  '006': { id: '006', name: '千千阙歌', singer: '陈慧娴', album: '永远的朋友', interval: 280, url: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3' },
  '007': { id: '007', name: '夜半歌声', singer: '张国荣', album: '夜半歌声', interval: 240, url: 'https://freetestdata.com/wp-content/uploads/2022/11/Free_Test_Data_500KB_MP3.mp3' },
  '008': { id: '008', name: '倩女幽魂', singer: '张国荣', album: '倩女幽魂', interval: 210, url: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3' },
  '009': { id: '009', name: '晴天', singer: '周杰伦', album: '叶惠美', interval: 270, url: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3' },
  '010': { id: '010', name: '稻香', singer: '周杰伦', album: '依然范特西', interval: 220, url: 'https://freetestdata.com/wp-content/uploads/2022/11/Free_Test_Data_500KB_MP3.mp3' },
  '011': { id: '011', name: '七里香', singer: '周杰伦', album: '七里香', interval: 250, url: 'https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_100KB_MP3.mp3' },
};

// 搜索歌曲
function searchSongs(keyword) {
  keyword = (keyword || '').toLowerCase();
  var results = [];
  for (var id in _songDatabase) {
    var song = _songDatabase[id];
    if (song.name.toLowerCase().indexOf(keyword) >= 0 ||
        song.singer.toLowerCase().indexOf(keyword) >= 0) {
      results.push(song);
    }
  }
  return results;
}

// 通过ID查找歌曲
function findSongById(id) {
  return _songDatabase[id] || null;
}

// 注册 LX Music 事件处理器（flutter_js 不支持 Promise.then，直接调用 setAsyncResult）
lx.on('request', function(params) {
  var source = params.source;
  var action = params.action;
  var info = params.info;
  var taskId = params._taskId;

  // ====== 榜单功能 ======
  if (action === 'leaderboard') {
    var list = [];
    for (var key in _leaderboardDatabase) {
      var board = _leaderboardDatabase[key];
      list.push({
        id: key,
        name: board.name,
        img: board.img,
        description: board.description,
        source: 'test_board'
      });
    }
    setAsyncResult(taskId, list);
    return;
  }

  if (action === 'leaderboardDetail') {
    var id = info.id;
    var board = _leaderboardDatabase[id];
    if (board) {
      setAsyncResult(taskId, {
        list: board.songs,
        updateTime: new Date().toLocaleDateString(),
        img: board.img,
        description: board.description
      });
    } else {
      setAsyncResult(taskId, { list: [], updateTime: '' });
    }
    return;
  }

  // ====== 基础功能 ======
  
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

    setAsyncResult(taskId, song.url);
    return;
  }

  // lyric: 获取歌词
  if (action === 'lyric') {
    var musicInfo = info.musicInfo || {};
    var id = musicInfo.id || musicInfo.songId || '';
    var song = findSongById(id);
    
    var lyric = song
      ? '[00:00.00] ' + song.name + '\n[00:05.00] 演唱：' + song.singer + '\n[00:10.00] 测试音源'
      : '[00:00.00] 暂无歌词';

    setAsyncResult(taskId, { lyric: lyric, tlyric: '' });
    return;
  }

  // pic: 获取封面
  if (action === 'pic') {
    var musicInfo = info.musicInfo || {};
    var id = musicInfo.id || musicInfo.songId || '';
    var song = findSongById(id);
    setAsyncResult(taskId, 'https://p2.music.126.net/6y-UleORITEDbvrOLV0Q8A==/5639395138885805.jpg');
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

  setAsyncError(taskId, 'Unknown action: ' + action);
});

// 发送初始化完成事件
lx.send('inited', {
  sources: {
    test_board: {
      name: '榜单测试音源',
      type: 'music',
      // 关键：必须声明支持 leaderboard 和 leaderboardDetail
      actions: ['musicUrl', 'lyric', 'pic', 'search', 'leaderboard', 'leaderboardDetail'],
      qualitys: ['128k', '320k', 'flac'],
    }
  },
  openDevTools: false,
});
