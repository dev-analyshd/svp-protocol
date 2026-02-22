import React from 'react';
import Document, { Html, Head, Main, NextScript } from 'next/document';

export default class MyDocument extends Document {
  render() {
    return (
      <Html lang="en">
        <Head>
          <meta charSet="utf-8" />
          <meta name="theme-color" content="#0ea5e9" />
          <meta name="description" content="SVP Protocol - Governance, Vault, and Dividend Management" />
        </Head>
        <body className="bg-white dark:bg-dark-950 text-gray-900 dark:text-gray-100">
          <Main />
          <NextScript />
        </body>
      </Html>
    );
  }
}
