/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { MessageCircle, Moon, Send, ArrowLeft, Sparkles, Volume2, VolumeX } from 'lucide-react';
import { getGalResponse } from './services/geminiService';

type Message = {
  id: string;
  text: string;
  sender: 'user' | 'gal';
  timestamp: Date;
};

export default function App() {
  const [view, setView] = useState<'home' | 'chat' | 'sleep'>('home');
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputText, setInputText] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const [isMuted, setIsMuted] = useState(true);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, isTyping]);

  const handleSendMessage = async () => {
    if (!inputText.trim()) return;

    const userMsg: Message = {
      id: Date.now().toString(),
      text: inputText,
      sender: 'user',
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMsg]);
    setInputText('');
    setIsTyping(true);

    const responseText = await getGalResponse(inputText);
    
    const galMsg: Message = {
      id: (Date.now() + 1).toString(),
      text: responseText,
      sender: 'gal',
      timestamp: new Date(),
    };

    setIsTyping(false);
    setMessages((prev) => [...prev, galMsg]);
  };

  return (
    <div className="min-h-screen bg-[#0F172A] text-slate-50 font-sans selection:bg-fuchsia-500/30 overflow-hidden relative">
      {/* Background Gradients */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-[10%] -left-[10%] w-[40%] h-[40%] bg-fuchsia-600/20 blur-[120px] rounded-full" />
        <div className="absolute top-[20%] -right-[10%] w-[50%] h-[50%] bg-violet-600/20 blur-[150px] rounded-full" />
        <div className="absolute -bottom-[10%] left-[20%] w-[60%] h-[40%] bg-indigo-600/10 blur-[100px] rounded-full" />
      </div>

      <AnimatePresence mode="wait">
        {view === 'home' && (
          <motion.div
            key="home"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="relative z-10 h-screen flex flex-col items-center justify-between p-8 pt-20"
          >
            <div className="text-center space-y-6">
              <motion.div
                animate={{ y: [0, -10, 0] }}
                transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
                className="w-32 h-32 mx-auto rounded-full bg-gradient-to-tr from-fuchsia-500 to-violet-500 p-1 shadow-2xl shadow-fuchsia-500/20"
              >
                <div className="w-full h-full rounded-full bg-[#0F172A] flex items-center justify-center overflow-hidden border-2 border-white/10">
                   <span className="text-4xl">💅</span>
                </div>
              </motion.div>
              
              <div className="space-y-2">
                <h1 className="text-2xl font-medium tracking-tight">今日もお疲れさま。</h1>
                <p className="text-slate-400 text-sm">溜め込んでない？全部聞くよ。</p>
              </div>
            </div>

            <div className="w-full max-w-md space-y-4">
              <button
                onClick={() => setView('chat')}
                className="w-full py-5 bg-gradient-to-r from-fuchsia-600 to-violet-600 rounded-2xl font-semibold text-lg shadow-lg shadow-fuchsia-900/20 active:scale-95 transition-transform flex items-center justify-center gap-3"
              >
                <MessageCircle size={24} />
                ちょっと聞いてほしい
              </button>
              
              <div className="flex gap-4">
                <button 
                  onClick={() => setIsMuted(!isMuted)}
                  className="flex-1 py-4 bg-white/5 border border-white/10 rounded-2xl text-sm flex items-center justify-center gap-2 hover:bg-white/10 transition-colors"
                >
                  {isMuted ? <VolumeX size={18} /> : <Volume2 size={18} />}
                  リラックス音
                </button>
                <button 
                  onClick={() => setView('sleep')}
                  className="flex-1 py-4 bg-white/5 border border-white/10 rounded-2xl text-sm flex items-center justify-center gap-2 hover:bg-white/10 transition-colors"
                >
                  <Moon size={18} />
                  そのまま寝る
                </button>
              </div>
            </div>

            <div className="text-slate-500 text-[10px] uppercase tracking-widest pb-4">
              Yoru-Gal MVP v1.0
            </div>
          </motion.div>
        )}

        {view === 'chat' && (
          <motion.div
            key="chat"
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="relative z-10 h-screen flex flex-col bg-[#0F172A]/80 backdrop-blur-xl"
          >
            {/* Header */}
            <header className="p-4 border-bottom border-white/5 flex items-center justify-between">
              <button onClick={() => setView('home')} className="p-2 hover:bg-white/5 rounded-full transition-colors">
                <ArrowLeft size={20} />
              </button>
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-fuchsia-500 to-violet-500 flex items-center justify-center text-xs">💅</div>
                <span className="font-medium">ギャルちゃん</span>
              </div>
              <button onClick={() => setView('sleep')} className="text-xs text-fuchsia-400 font-medium px-3 py-1 bg-fuchsia-400/10 rounded-full">
                寝る
              </button>
            </header>

            {/* Messages Area */}
            <div className="flex-1 overflow-y-auto p-4 space-y-6 scrollbar-hide">
              {messages.length === 0 && (
                <div className="h-full flex flex-col items-center justify-center text-center space-y-4 opacity-50">
                  <Sparkles size={40} className="text-fuchsia-400" />
                  <p className="text-sm">何でも吐き出しちゃいな。<br/>うちらだけの秘密だよん。</p>
                </div>
              )}
              {messages.map((msg) => (
                <motion.div
                  key={msg.id}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className={`flex ${msg.sender === 'user' ? 'justify-end' : 'justify-start'}`}
                >
                  <div
                    className={`max-w-[80%] p-4 rounded-2xl text-sm leading-relaxed ${
                      msg.sender === 'user'
                        ? 'bg-violet-600 text-white rounded-tr-none'
                        : 'bg-white/10 text-slate-200 rounded-tl-none border border-white/5'
                    }`}
                  >
                    {msg.text}
                  </div>
                </motion.div>
              ))}
              {isTyping && (
                <div className="flex justify-start">
                  <div className="bg-white/10 p-4 rounded-2xl rounded-tl-none flex gap-1">
                    <motion.div animate={{ opacity: [0.3, 1, 0.3] }} transition={{ repeat: Infinity, duration: 1 }} className="w-1.5 h-1.5 bg-slate-400 rounded-full" />
                    <motion.div animate={{ opacity: [0.3, 1, 0.3] }} transition={{ repeat: Infinity, duration: 1, delay: 0.2 }} className="w-1.5 h-1.5 bg-slate-400 rounded-full" />
                    <motion.div animate={{ opacity: [0.3, 1, 0.3] }} transition={{ repeat: Infinity, duration: 1, delay: 0.4 }} className="w-1.5 h-1.5 bg-slate-400 rounded-full" />
                  </div>
                </div>
              )}
              <div ref={messagesEndRef} />
            </div>

            {/* Input Area */}
            <div className="p-4 pb-8 bg-gradient-to-t from-[#0F172A] to-transparent">
              <div className="relative flex items-center">
                <input
                  type="text"
                  value={inputText}
                  onChange={(e) => setInputText(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleSendMessage()}
                  placeholder="ここに愚痴を書いてね..."
                  className="w-full bg-white/5 border border-white/10 rounded-2xl py-4 pl-5 pr-14 focus:outline-none focus:border-fuchsia-500/50 transition-colors text-sm"
                />
                <button
                  onClick={handleSendMessage}
                  disabled={!inputText.trim() || isTyping}
                  className="absolute right-2 p-2 bg-fuchsia-600 rounded-xl disabled:opacity-50 disabled:bg-slate-700 transition-all"
                >
                  <Send size={18} />
                </button>
              </div>
            </div>
          </motion.div>
        )}

        {view === 'sleep' && (
          <motion.div
            key="sleep"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="relative z-10 h-screen flex flex-col items-center justify-center p-8 bg-black"
          >
            <motion.div
              animate={{ scale: [1, 1.1, 1], opacity: [0.5, 0.8, 0.5] }}
              transition={{ duration: 8, repeat: Infinity }}
              className="absolute inset-0 bg-gradient-to-b from-indigo-900/20 to-black pointer-events-none"
            />
            
            <div className="text-center space-y-12 relative z-20">
              <Moon size={64} className="mx-auto text-indigo-300/50" />
              <div className="space-y-4">
                <h2 className="text-2xl font-light tracking-widest">おやすみなさい</h2>
                <p className="text-slate-500 text-sm">明日のことは、明日考えよ。</p>
              </div>
              
              <button
                onClick={() => setView('home')}
                className="px-8 py-3 rounded-full border border-white/10 text-xs text-slate-500 hover:text-slate-300 transition-colors"
              >
                戻る
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
