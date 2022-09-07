/** @format */
import { Fragment } from 'react';
import type { AppProps } from 'next/app';
import Head from 'next/head';
import './styles.css';

function App({ Component, pageProps }: AppProps): JSX.Element {
    return (
        <Fragment>
            <Head>
                <title>Loot Dungeon Test Harness</title>
            </Head>
            <Component {...pageProps} />
        </Fragment>
    );
}

export default App;
