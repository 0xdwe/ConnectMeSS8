import { useState } from 'react';
import logoImg from '../../imports/image-removebg-preview_(6).png';
import mascotsImg from '../../imports/ChatGPT_Image_May_3,_2026,_06_41_29_PM-1.png';

interface AuthScreenProps {
  onLogin: (email: string, password: string) => void;
}

export function AuthScreen({ onLogin }: AuthScreenProps) {
  const [showForm, setShowForm] = useState(false);
  const [isSignup, setIsSignup] = useState(false);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onLogin(email, password);
  };

  if (!showForm) {
    return (
      <div
        className="min-h-screen flex flex-col items-center justify-center p-6 relative overflow-hidden"
        style={{
          background: 'linear-gradient(180deg, #8E9BC3 0%, #B8C5E8 50%, #C8B6E2 100%)'
        }}
      >
        {/* Decorative Stars */}
        <div className="absolute top-12 left-8 text-white opacity-60 text-xl">✦</div>
        <div className="absolute top-24 right-12 text-white opacity-40 text-sm">✦</div>
        <div className="absolute bottom-32 left-16 text-white opacity-50 text-base">✦</div>

        <div className="w-full max-w-xl flex flex-col items-center -mt-8">
          {/* Logo */}
          <img
            src={logoImg}
            alt="Connect Me Logo"
            className="h-16 mb-3"
            style={{ width: 'auto' }}
          />

          {/* Title */}
          <h1 className="text-5xl font-bold mb-1 text-center px-4" style={{ color: '#1B1B1B', letterSpacing: '-0.02em' }}>
            Connect Me
          </h1>
          <p className="text-sm font-medium text-center mb-2 px-4" style={{ color: '#1B1B1B' }}>
            Your way to nurture and grow meaningful relationships.
          </p>

          {/* Mascots - Full Width matching button */}
          <div className="w-full mb-2">
            <img
              src={mascotsImg}
              alt="Connect Me Mascots"
              className="w-full h-auto object-contain"
            />
          </div>

          {/* Get Started Button */}
          <button
            onClick={() => setShowForm(true)}
            className="w-full py-4 text-white rounded-full hover:scale-105 transition-all font-bold text-base shadow-lg"
            style={{
              backgroundColor: '#7C34ED'
            }}
          >
            Get Started
          </button>
        </div>
      </div>
    );
  }

  return (
    <div
      className="min-h-screen flex items-center justify-center p-4 relative overflow-hidden"
      style={{
        background: 'linear-gradient(180deg, #8E9BC3 0%, #B8C5E8 50%, #C8B6E2 100%)'
      }}
    >
      {/* Decorative Stars */}
      <div className="absolute top-12 left-8 text-white opacity-60 text-xl">✦</div>
      <div className="absolute top-24 right-12 text-white opacity-40 text-sm">✦</div>
      <div className="absolute bottom-12 left-8 text-white opacity-50 text-base">✦</div>
      <div className="absolute top-1/3 right-20 text-white opacity-30 text-base">✦</div>
      <div className="absolute bottom-1/3 right-8 text-white opacity-40 text-sm">✦</div>

      <div className="w-full max-w-md">
        <div className="bg-white rounded-3xl shadow-2xl p-8">
          {/* Back Button */}
          <button
            onClick={() => setShowForm(false)}
            className="mb-6 text-lg font-semibold hover:opacity-80 transition-opacity flex items-center"
            style={{ color: '#7C34ED' }}
          >
            ← Back
          </button>

          {/* Logo */}
          <div className="flex justify-center mb-4">
            <img
              src={logoImg}
              alt="Connect Me Logo"
              className="h-12"
              style={{ width: 'auto', filter: 'brightness(0) saturate(100%) invert(45%) sepia(25%) saturate(1200%) hue-rotate(220deg) brightness(90%) contrast(90%)' }}
            />
          </div>

          <h2 className="text-3xl font-bold mb-2 text-center" style={{ color: '#1B1B1B' }}>
            {isSignup ? 'Create Account' : 'Welcome Back'}
          </h2>
          <p className="text-center mb-8 font-medium" style={{ color: '#6B7280' }}>
            {isSignup ? 'Join Connect Me today' : 'Sign in to continue'}
          </p>

          <form onSubmit={handleSubmit} className="space-y-4">
            {isSignup && (
              <div>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full px-4 py-4 rounded-2xl focus:outline-none focus:ring-2 transition-all"
                  placeholder="Name"
                  required={isSignup}
                  style={{
                    backgroundColor: '#F9F6FF',
                    color: '#1B1B1B'
                  }}
                  onFocus={(e) => {
                    e.currentTarget.style.boxShadow = '0 0 0 3px rgba(124, 52, 237, 0.3)';
                  }}
                  onBlur={(e) => {
                    e.currentTarget.style.boxShadow = '';
                  }}
                />
              </div>
            )}

            <div>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full px-4 py-4 rounded-2xl focus:outline-none focus:ring-2 transition-all"
                placeholder="Email"
                required
                style={{
                  backgroundColor: '#F9F6FF',
                  color: '#1B1B1B'
                }}
                onFocus={(e) => {
                  e.currentTarget.style.boxShadow = '0 0 0 3px rgba(124, 52, 237, 0.3)';
                }}
                onBlur={(e) => {
                  e.currentTarget.style.boxShadow = '';
                }}
              />
            </div>

            <div>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-4 py-4 rounded-2xl focus:outline-none focus:ring-2 transition-all"
                placeholder="Password"
                required
                style={{
                  backgroundColor: '#F9F6FF',
                  color: '#1B1B1B'
                }}
                onFocus={(e) => {
                  e.currentTarget.style.boxShadow = '0 0 0 3px rgba(124, 52, 237, 0.3)';
                }}
                onBlur={(e) => {
                  e.currentTarget.style.boxShadow = '';
                }}
              />
            </div>

            <button
              type="submit"
              className="w-full py-4 text-white rounded-full hover:scale-105 transition-all font-bold text-lg shadow-lg mt-6"
              style={{
                backgroundColor: '#7C34ED'
              }}
            >
              {isSignup ? 'Sign Up' : 'Login'}
            </button>
          </form>

          <div className="mt-6 text-center">
            <button
              onClick={() => setIsSignup(!isSignup)}
              className="text-sm font-semibold hover:opacity-80 transition-opacity"
              style={{ color: '#7C34ED' }}
            >
              {isSignup ? 'Already have an account? Login' : "Don't have an account? Sign Up"}
            </button>
          </div>
        </div>

        <p className="text-center text-xs mt-6 font-medium" style={{ color: '#6B7280' }}>
          By continuing, you agree to our Terms of Service and Privacy Policy
        </p>
      </div>
    </div>
  );
}
